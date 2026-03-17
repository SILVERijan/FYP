import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/transport_route.dart';
import '../models/vehicle.dart';
import '../models/stop.dart';
import '../api_service.dart';
import 'package:frontend/widgets/app_drawer.dart';
import 'package:frontend/screens/main_screen.dart';

class MapTrackingScreen extends StatefulWidget {
  final TransportRoute? route;
  final bool showAppBar;
  const MapTrackingScreen({super.key, this.route, this.showAppBar = true});

  @override
  State<MapTrackingScreen> createState() => _MapTrackingScreenState();
}

class _MapTrackingScreenState extends State<MapTrackingScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<Vehicle> _vehicles = [];
  Timer? _timer;
  final MapController _mapController = MapController();
  late AnimationController _pulseController;
  DateTime _lastUpdated = DateTime.now();
  TransportRoute? _detailedRoute;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    if (widget.route != null) {
      _fetchRouteDetails();
    }
    
    _fetchVehicles();
    // Poll for vehicle locations every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) => _fetchVehicles());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchRouteDetails() async {
    try {
      final detailed = await _apiService.getRouteDetails(widget.route!.id);
      setState(() {
        _detailedRoute = detailed;
      });
      _centerMapOnRoute();
    } catch (e) {
      debugPrint('Error fetching route details: $e');
    }
  }

  Future<void> _fetchVehicles() async {
    try {
      final vehicles = await _apiService.getVehicles();
      setState(() {
        if (widget.route != null) {
          _vehicles = vehicles.where((v) => v.route?.id == widget.route!.id).toList();
        } else {
          _vehicles = vehicles;
        }
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      debugPrint('Error fetching vehicles: $e');
    }
  }

  void _centerMapOnRoute() {
    if (_detailedRoute != null && _detailedRoute!.stops != null && _detailedRoute!.stops!.isNotEmpty) {
       _mapController.move(LatLng(_detailedRoute!.stops!.first.latitude, _detailedRoute!.stops!.first.longitude), 13.0);
    }
  }

  void _centerMap() {
    if (_vehicles.isNotEmpty) {
      _mapController.move(LatLng(_vehicles.first.latitude, _vehicles.first.longitude), 14.0);
    } else if (_detailedRoute != null && _detailedRoute!.stops != null && _detailedRoute!.stops!.isNotEmpty) {
      _mapController.move(LatLng(_detailedRoute!.stops!.first.latitude, _detailedRoute!.stops!.first.longitude), 13.0);
    } else {
       _mapController.move(LatLng(27.7000, 85.3000), 13.0);
    }
  }

  List<LatLng> _buildPolylinePoints() {
    // Prefer backend polyline (actual road geometry) if available
    if (_detailedRoute?.polyline != null && _detailedRoute!.polyline!.isNotEmpty) {
      return _detailedRoute!.polyline!
          .map((pt) => LatLng(pt[0], pt[1]))
          .toList();
    }
    // Fall back to connecting stops in order
    if (_detailedRoute?.stops != null) {
      return _detailedRoute!.stops!
          .map((s) => LatLng(s.latitude, s.longitude))
          .toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandRed = theme.colorScheme.primary;
    const Color bgWhite = Color(0xFFF5F5F5);
    final surfaceWhite = theme.colorScheme.surface;

    return Scaffold(
      backgroundColor: bgWhite,
      appBar: widget.showAppBar ? AppBar(
        title: Text(widget.route?.name ?? "All Vehicles"),
      ) : null,
      drawer: widget.showAppBar ? AppDrawer(
        selectedIndex: 0,
        onItemSelected: (index) {
          if (index != 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainScreen()),
            );
          }
        },
      ) : null,
      body: Stack(
        children: [
          // The Map Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(27.7000, 85.3000), // Kathmandu
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.example.frontend',
              ),
              if (_detailedRoute != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _buildPolylinePoints(),
                      color: Colors.blueAccent.withOpacity(0.8),
                      strokeWidth: 4.5,
                      borderStrokeWidth: 1.5,
                      borderColor: Colors.blue[900]!,
                    )
                  ],
                ),
              if (_detailedRoute != null && _detailedRoute!.stops != null)
                 MarkerLayer(
                   markers: _detailedRoute!.stops!.map((s) {
                     return Marker(
                       point: LatLng(s.latitude, s.longitude),
                       width: 12, height: 12,
                       child: Container(
                         decoration: BoxDecoration(
                           color: Colors.white,
                           shape: BoxShape.circle,
                           border: Border.all(color: Colors.blueAccent, width: 2.5)
                         ),
                       ),
                     );
                   }).toList(),
                 ),
              MarkerLayer(
                markers: _vehicles.map((v) {
                  return Marker(
                    point: LatLng(v.latitude, v.longitude),
                    width: 70,
                    height: 70,
                    child: _buildAnimatedMarker(v, brandRed),
                  );
                }).toList(),
              ),
            ],
          ),

          // Top Floating Header - Only show if NO AppBar
          if (!widget.showAppBar)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: _buildFloatingHeader(context, surfaceWhite),
            ),

          // Floating Controls (My Location)
          Positioned(
            right: 16,
            bottom: 240, // Above bottom sheet
            child: FloatingActionButton(
              backgroundColor: surfaceWhite,
              foregroundColor: Colors.black87,
              elevation: 4,
              heroTag: 'centerMap',
              onPressed: _centerMap,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Bottom Sheet Panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomPanel(surfaceWhite, brandRed),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedMarker(Vehicle vehicle, Color brandRed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Plate Number Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: brandRed, width: 1.5),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0,2))],
          ),
          child: Text(
            vehicle.plateNumber,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black87),
          ),
        ),
        const SizedBox(height: 4),
        // Pulsing Dot
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 24 + (_pulseController.value * 8),
              height: 24 + (_pulseController.value * 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brandRed.withOpacity(0.3 + (_pulseController.value * 0.4)),
                border: Border.all(color: brandRed, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: brandRed.withOpacity(0.5 * _pulseController.value),
                    blurRadius: 10,
                    spreadRadius: 5 * _pulseController.value,
                  )
                ]
              ),
              child: const Center(
                child: Icon(Icons.directions_bus, color: Colors.white, size: 14),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFloatingHeader(BuildContext context, Color surfaceWhite) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: surfaceWhite.withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          if (widget.route != null)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            )
          else
            const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.route?.name ?? "All Vehicles",
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.map_outlined, color: Colors.black87, size: 20),
          )
        ],
      ),
    );
  }

  Widget _buildBottomPanel(Color surfaceWhite, Color brandRed) {
    return Container(
        height: 220,
        decoration: BoxDecoration(
          color: surfaceWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -5))],
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Live Status",
                        style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${_vehicles.length} Vehicles Active",
                        style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: brandRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: brandRed.withOpacity(0.5))
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text('Updated ${timeago.format(_lastUpdated, locale: 'en_short')}', style: TextStyle(color: brandRed, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const Divider(color: Colors.black12, height: 24),
            // Vehicle List
            Expanded(
              child: _vehicles.isEmpty 
              ? const Center(child: Text("No vehicles currently on this route", style: TextStyle(color: Colors.black54)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _vehicles.length,
                  itemBuilder: (context, index) {
                    final v = _vehicles[index];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.directions_bus, color: brandRed, size: 20),
                      ),
                      title: Text(v.plateNumber, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Tracking En Route", style: TextStyle(color: Colors.black54, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.black26),
                      onTap: () {
                         _mapController.move(LatLng(v.latitude, v.longitude), 16.0);
                      },
                    );
                  },
                )
            ),
          ],
        )
    );
  }
}
