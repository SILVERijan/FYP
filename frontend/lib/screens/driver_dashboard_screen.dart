import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../api_service.dart';
import '../models/vehicle.dart';
import '../models/user.dart';

class DriverDashboardScreen extends StatefulWidget {
  final User user;
  const DriverDashboardScreen({super.key, required this.user});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();
  
  List<Vehicle> _vehicles = [];
  Vehicle? _selectedVehicle;
  bool _isTracking = false;
  bool _isLoading = true;
  bool _autoFollow = true;
  bool _showRoute = true;
  
  LatLng _currentLocation = const LatLng(27.7172, 85.3240); // Default Kathmandu
  Timer? _timer;
  String _statusMessage = "Select a vehicle to start";

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
    _initLocation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  List<LatLng> _getRoutePoints() {
    if (_selectedVehicle?.route?.polyline == null) return [];
    return _selectedVehicle!.route!.polyline!.map((pt) => LatLng(pt[0], pt[1])).toList();
  }

  Color _getRouteColor() {
    if (_selectedVehicle?.route?.color == null) return Colors.blue;
    try {
      return Color(int.parse(_selectedVehicle!.route!.color.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  Future<void> _initLocation() async {
    bool hasPermission = await _handleLocationPermission();
    if (hasPermission) {
      Position pos = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
      });
      _mapController.move(_currentLocation, 15);
    }
  }

  Future<void> _fetchVehicles() async {
    try {
      final vehicles = await _apiService.getDriverVehicles();
      setState(() {
        _vehicles = vehicles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading vehicles: $e');
    }
  }

  Future<void> _toggleTracking(bool value) async {
    if (_selectedVehicle == null) {
      _showSnackBar('Please select a vehicle first');
      return;
    }

    if (value) {
      bool hasPermission = await _handleLocationPermission();
      if (!hasPermission) return;

      setState(() {
        _isTracking = true;
        _statusMessage = "Tracking active...";
      });

      _updateLocation();
      _timer = Timer.periodic(const Duration(seconds: 7), (timer) => _updateLocation());
    } else {
      _timer?.cancel();
      setState(() {
        _isTracking = false;
        _statusMessage = "Tracking stopped";
      });
      
      _apiService.updateDriverLocation(
        vehicleId: _selectedVehicle!.id,
        latitude: 0, 
        longitude: 0,
        status: 'inactive',
      );
    }
  }

  Future<void> _updateLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      LatLng newPos = LatLng(position.latitude, position.longitude);

      await _apiService.updateDriverLocation(
        vehicleId: _selectedVehicle!.id,
        latitude: position.latitude,
        longitude: position.longitude,
        status: 'active',
      );
      
      if (mounted) {
        setState(() {
          _currentLocation = newPos;
          _statusMessage = "Last update: ${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}";
          if (_autoFollow) {
            _mapController.move(newPos, _mapController.camera.zoom);
          }
        });
      }
    } catch (e) {
      debugPrint("Location update failed: $e");
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Location services are disabled.');
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    return permission != LocationPermission.deniedForever;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final routePoints = _getRoutePoints();
    final routeStops = _selectedVehicle?.route?.stops ?? [];

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.black))
        : Stack(
            children: [
              // 1. FULL SCREEN MAP
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentLocation,
                  initialZoom: 15,
                  onPositionChanged: (pos, hasGesture) {
                    if (hasGesture && _autoFollow) {
                      setState(() => _autoFollow = false);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.frontend',
                  ),
                  
                  // Route Polyline
                  if (_showRoute && routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          color: _getRouteColor(),
                          strokeWidth: 5.0,
                        ),
                      ],
                    ),

                  // Route Stops
                  if (_showRoute && routeStops.isNotEmpty)
                    MarkerLayer(
                      markers: routeStops.map((s) => Marker(
                        point: LatLng(s.latitude, s.longitude),
                        width: 20,
                        height: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getRouteColor(),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3, offset: const Offset(0, 1))],
                          ),
                          child: const Icon(Icons.directions_bus, color: Colors.white, size: 10),
                        ),
                      )).toList(),
                    ),

                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation,
                        width: 80,
                        height: 80,
                        child: _buildDriverMarker(),
                      ),
                    ],
                  ),
                ],
              ),

              // 2. GLASSMORPHISM TOP HEADER
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: _buildGlassHeader(),
              ),

              // 3. BOTTOM CONTROL PANEL
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: _buildGlassControlPanel(),
              ),

              // 4. FLOATING ACTION BUTTONS (Recenter)
              if (!_autoFollow)
                Positioned(
                  bottom: 340,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: 'recenter',
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: () {
                      setState(() => _autoFollow = true);
                      _mapController.move(_currentLocation, 15);
                    },
                    child: const Icon(Icons.my_location_rounded, color: Colors.blue),
                  ).animate().scale(),
                ),
            ],
          ),
    );
  }

  Widget _buildDriverMarker() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 20),
        ),
        Icon(Icons.location_on_rounded, color: Colors.red[800], size: 40),
      ],
    ).animate(onPlay: (controller) => controller.repeat(reverse: true)).moveY(begin: -5, end: 5, duration: 1.seconds);
  }

  Widget _buildGlassHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.black,
                backgroundImage: widget.user.profile_picture != null 
                  ? NetworkImage(_apiService.getProfileImageUrl(widget.user.profile_picture))
                  : null,
                child: widget.user.profile_picture == null ? const Icon(Icons.person, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.user.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    Text(widget.user.company_name ?? "No Company", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                child: const Text("DRIVER", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ],
          ),
        ),
      ).animate().fadeIn().slideY(begin: -0.2),
    );
  }

  Widget _buildGlassControlPanel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Vehicle Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Vehicle>(
                    value: _selectedVehicle,
                    isExpanded: true,
                    hint: const Text("Choose Your Vehicle", style: TextStyle(fontWeight: FontWeight.bold)),
                    items: _vehicles.map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v.plateNumber, style: const TextStyle(fontWeight: FontWeight.w800)),
                    )).toList(),
                    onChanged: _isTracking ? null : (v) => setState(() => _selectedVehicle = v),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 2. Map Layers Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.layers_outlined, size: 18, color: Colors.blue[800]),
                      const SizedBox(width: 8),
                      const Text(
                        "Route Navigation Overlay",
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: -0.2),
                      ),
                    ],
                  ),
                  _selectedVehicle?.route == null
                    ? const Text("No route", style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold))
                    : Switch.adaptive(
                        value: _showRoute,
                        activeColor: _getRouteColor(),
                        onChanged: (v) => setState(() => _showRoute = v),
                      ),
                ],
              ),
              const SizedBox(height: 20),
              
              const Divider(height: 1),
              const SizedBox(height: 20),

              // 3. Tracking Control Area
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isTracking ? "LIVE" : "START",
                        style: TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.w900, 
                          color: _isTracking ? Colors.green : Colors.black,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        _selectedVehicle?.route != null 
                            ? "On Route: ${_selectedVehicle!.route!.name}" 
                            : _statusMessage, 
                        style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w600)
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => _toggleTracking(!_isTracking),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _isTracking ? Colors.red.withOpacity(0.1) : Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                           if (!_isTracking) BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))
                        ],
                      ),
                      child: Icon(
                        _isTracking ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        color: _isTracking ? Colors.red : Colors.white,
                        size: 36,
                      ).animate(target: _isTracking ? 1 : 0).shimmer(),
                    ),
                  ),
                ],
              ),
              if (_isTracking)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: const LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    color: Colors.green,
                  ).animate().shimmer(duration: 2.seconds),
                ),
            ],
          ),
        ),
      ).animate().fadeIn().slideY(begin: 0.2),
    );
  }
}
