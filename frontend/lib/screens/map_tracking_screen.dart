import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_animate/flutter_animate.dart';
import '../models/transport_route.dart';
import '../models/vehicle.dart';
import '../models/stop.dart';
import '../api_service.dart';
import '../theme/app_theme.dart';

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
  DateTime _lastUpdated = DateTime.now();
  TransportRoute? _detailedRoute;
  List<int> _selectedRouteIds = [];
  List<TransportRoute> _allRoutes = [];
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    
    if (widget.route != null) {
      _fetchRouteDetails();
    } else {
      _fetchAllRoutes();
    }
    
    _fetchVehicles();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) => _fetchVehicles());
  }

  Future<void> _fetchAllRoutes() async {
    try {
      final routes = await _apiService.getRoutes();
      if (mounted) setState(() => _allRoutes = routes);
    } catch (e) {
      debugPrint('Error fetching all routes: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRouteDetails() async {
    try {
      final detailed = await _apiService.getRouteDetails(widget.route!.id);
      if (mounted) {
        setState(() => _detailedRoute = detailed);
        _centerMapOnRoute();
      }
    } catch (e) {
      debugPrint('Error fetching route details: $e');
    }
  }

  Future<void> _fetchVehicles() async {
    try {
      List<int>? routeIdsToFetch;
      if (widget.route != null) {
        routeIdsToFetch = [widget.route!.id];
      } else if (_selectedRouteIds.isNotEmpty) {
        routeIdsToFetch = _selectedRouteIds;
      } else if (widget.route == null && _selectedRouteIds.isEmpty) {
        if (mounted) setState(() => _vehicles = []);
        return;
      }

      final vehicles = await _apiService.getVehicles(routeIds: routeIdsToFetch);
      if (mounted) {
        setState(() {
          _vehicles = vehicles;
          _lastUpdated = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('Error fetching vehicles: $e');
    }
  }

  void _centerMapOnRoute() {
    if (_detailedRoute?.stops?.isNotEmpty ?? false) {
       _mapController.move(LatLng(_detailedRoute!.stops!.first.latitude, _detailedRoute!.stops!.first.longitude), 13.0);
    }
  }

  void _centerOnUser() {
    if (_vehicles.isNotEmpty) {
      _mapController.move(LatLng(_vehicles.first.latitude, _vehicles.first.longitude), 14.5);
    } else {
       _mapController.move(const LatLng(27.7000, 85.3000), 13.0);
    }
  }

  List<LatLng> _buildPolylinePoints() {
    if (_detailedRoute?.polyline?.isNotEmpty ?? false) {
      return _detailedRoute!.polyline!.map((pt) => LatLng(pt[0], pt[1])).toList();
    }
    if (_detailedRoute?.stops != null) {
      return _detailedRoute!.stops!.map((s) => LatLng(s.latitude, s.longitude)).toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. The Map
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(27.7000, 85.3000),
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.frontend',
              ),
              if (_detailedRoute != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _buildPolylinePoints(),
                      color: const Color(0xFF985A26),
                      strokeWidth: 6.0,
                    ),
                  ],
                ),
              markerLayer(),
            ],
          ),

          // 2. Floating Header (Uber Style)
          if (!widget.showAppBar)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: _buildUberHeader(),
            ),

          // 3. Draggable Scrollable Sheet (Citymapper Style)
          _buildDraggableSheet(),

          // 4. Floating Action Buttons (Minimalist)
          Positioned(
            right: 16,
            bottom: 120, // Keep above the collapsed sheet handle
            child: Column(
              children: [
                _buildFloatingButton(
                  icon: Icons.my_location_rounded,
                  onPressed: _centerOnUser,
                ),
                const SizedBox(height: 12),
                _buildFloatingButton(
                  icon: Icons.layers_outlined,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget markerLayer() {
    return MarkerLayer(
      markers: [
        ...(_detailedRoute?.stops ?? []).map((s) => Marker(
          point: LatLng(s.latitude, s.longitude),
          width: 24, height: 24,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF985A26), 
              shape: BoxShape.circle, 
              border: Border.all(color: Colors.white, width: 2)
            ),
            child: const Icon(Icons.directions_bus, color: Colors.white, size: 14),
          ),
        )),
        ..._vehicles.map((v) => Marker(
          point: LatLng(v.latitude, v.longitude),
          width: 80, height: 60,
          child: _buildVehicleMarker(v),
        )),
      ],
    );
  }

  Widget _buildVehicleMarker(Vehicle v) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 60),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black, 
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            v.plateNumber, 
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1.2)
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 22, height: 22,
          decoration: const BoxDecoration(
            color: Colors.black, 
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.directions_bus, color: Colors.white, size: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildUberHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppTheme.glassDecoration.copyWith(borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          if (widget.route != null)
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
            )
          else
            const Icon(Icons.menu_rounded, color: Colors.black87),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.route?.name ?? (_selectedRouteIds.isEmpty ? "Track Transit" : "${_selectedRouteIds.length} Routes Tracking"),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.route == null)
            IconButton(
              icon: const Icon(Icons.tune_rounded, color: Colors.black87, size: 20),
              onPressed: _showRouteFilterSheet,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  Widget _buildFloatingButton({required IconData icon, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48, width: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Icon(icon, color: Colors.black87, size: 22),
      ),
    );
  }

  Widget _buildDraggableSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.25,
      minChildSize: 0.1,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))],
          ),
          child: Column(
            children: [
              _buildSheetHandle(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildSheetHeader(),
                    const SizedBox(height: 24),
                    if (_vehicles.isEmpty)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Text("No vehicles active on selected routes", style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w600)),
                      ))
                    else
                      ..._vehicles.map((v) => _buildVehicleListTile(v)),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        height: 5, width: 40,
        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2.5)),
      ),
    );
  }

  Widget _buildSheetHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Transit Status", style: TextStyle(color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text("${_vehicles.length} En Route", style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.w900)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppTheme.neutralGrey, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(timeago.format(_lastUpdated, locale: 'en_short'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleListTile(Vehicle v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.neutralGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () {
          _mapController.move(LatLng(v.latitude, v.longitude), 16.0);
          _sheetController.animateTo(0.1, duration: 400.ms, curve: Curves.easeOutCubic);
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
          child: const Icon(Icons.directions_bus_filled_rounded, color: Colors.white, size: 20),
        ),
        title: Text(v.plateNumber, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        subtitle: Text(v.route?.name ?? "On Duty", style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.w600, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
      ),
    );
  }

  void _showRouteFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(
                children: [
                  _buildSheetHandle(),
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text("Filter Routes", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _allRoutes.length,
                      itemBuilder: (context, index) {
                        final route = _allRoutes[index];
                        final isSelected = _selectedRouteIds.contains(route.id);
                        return ListTile(
                          title: Text(route.name, style: TextStyle(fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600)),
                          subtitle: Text(route.type),
                          trailing: Icon(isSelected ? Icons.check_circle_rounded : Icons.circle_outlined, color: isSelected ? Colors.black : Colors.black12),
                          onTap: () {
                            setModalState(() {
                              if (isSelected) _selectedRouteIds.remove(route.id);
                              else _selectedRouteIds.add(route.id);
                            });
                            setState(() {});
                            _fetchVehicles();
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Apply Filter"),
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }
}
