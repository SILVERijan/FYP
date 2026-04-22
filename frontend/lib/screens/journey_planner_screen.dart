import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import '../api_service.dart';
import '../theme/app_theme.dart';
import '../models/stop.dart';
import '../models/transport_route.dart';
import '../widgets/journey_result_card.dart';
import 'dart:async';
import 'dart:ui';

class JourneyPlannerScreen extends StatefulWidget {
  const JourneyPlannerScreen({super.key});

  @override
  State<JourneyPlannerScreen> createState() => _JourneyPlannerScreenState();
}

class _JourneyPlannerScreenState extends State<JourneyPlannerScreen> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();
  
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destController = TextEditingController();
  
  List<Map<String, dynamic>> _startSuggestions = [];
  List<Map<String, dynamic>> _destSuggestions = [];
  
  Map<String, dynamic>? _selectedStart;
  Map<String, dynamic>? _selectedDest;
  
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selectedJourney;
  bool _isSearching = false;
  bool _isLoadingLocation = false;
  
  LatLng? _currentUserLocation;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _initLocationService();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _startController.dispose();
    _destController.dispose();
    super.dispose();
  }

  Future<void> _initLocationService() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentUserLocation = LatLng(position.latitude, position.longitude);
    });

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentUserLocation = LatLng(position.latitude, position.longitude);
        });
      }
    });
  }

  Future<void> _getSuggestions(String query, bool isStart) async {
    if (query.length < 2) {
      setState(() {
        if (isStart) _startSuggestions = []; else _destSuggestions = [];
      });
      return;
    }
    
    try {
      final suggestions = await _apiService.suggestStops(query);
      setState(() {
        if (isStart) _startSuggestions = suggestions; else _destSuggestions = suggestions;
      });
    } catch (e) {
      debugPrint('Error getting suggestions: $e');
    }
  }

  Future<void> _searchRoutes() async {
    if (_selectedStart == null || _selectedDest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both start and destination')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _results = [];
      _selectedJourney = null;
    });

    try {
      final routes = await _apiService.findRoutes(
        startLat: _selectedStart!['latitude'],
        startLng: _selectedStart!['longitude'],
        destLat: _selectedDest!['latitude'],
        destLng: _selectedDest!['longitude'],
      );
      setState(() => _results = routes);
      
      if (routes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No routes found between these locations.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search error: $e')),
      );
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _focusOnStop(double lat, double lng) {
    _mapController.move(LatLng(lat, lng), 16.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentUserLocation ?? const LatLng(27.7000, 85.3000),
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              // TODO: Add Polylines and Markers for selected journey
              if (_selectedJourney != null) PolylineLayer(
                polylines: _buildPolylines(),
              ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // 2. Floating Search Panel
          Positioned(
            left: 40,
            top: 40,
            child: _buildSearchPanel(),
          ),

          // 3. Floating Follow the Route Panel (Result Details)
          if (_selectedJourney != null)
            Positioned(
              left: 380, // Side by side with search if open
              top: 40,
              bottom: 40,
              child: _buildFollowRoutePanel(),
            ),
          
          // 4. Results Picker (Small floating cards if multiple results)
          if (_results.isNotEmpty && _selectedJourney == null)
            Positioned(
              right: 40,
              top: 40,
              bottom: 40,
              width: 400,
              child: _buildResultsPicker(),
            ),
        ],
      ),
    );
  }


  Widget _buildSearchPanel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF141414).withOpacity(0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Journey',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1),
                  ),
                  if (_results.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                      onPressed: () => setState(() { _results = []; _selectedJourney = null; }),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              _buildFieldLabel('From'),
              _buildSearchInput(_startController, (val) => _getSuggestions(val, true), _startSuggestions, (stop) {
                setState(() {
                  _selectedStart = stop;
                  _startController.text = stop['name'];
                  _startSuggestions = [];
                });
              }),
              const SizedBox(height: 16),
              Center(child: Icon(Icons.swap_vert, color: Colors.white24, size: 20)),
              const SizedBox(height: 8),
              _buildFieldLabel('To'),
              _buildSearchInput(_destController, (val) => _getSuggestions(val, false), _destSuggestions, (stop) {
                setState(() {
                  _selectedDest = stop;
                  _destController.text = stop['name'];
                  _destSuggestions = [];
                });
              }),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSearching ? null : _searchRoutes,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentCrimson,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSearching 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Find Routes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideX(begin: -0.1);
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      ),
    );
  }

  Widget _buildSearchInput(TextEditingController controller, Function(String) onChanged, List<Map<String, dynamic>> suggestions, Function(Map<String, dynamic>) onSelect) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              fillColor: Colors.transparent,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: Icon(Icons.location_on_outlined, color: Colors.white24, size: 18),
            ),
          ),
        ),
        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
              boxShadow: [const BoxShadow(color: Colors.black54, blurRadius: 20)],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final s = suggestions[index];
                return ListTile(
                  dense: true,
                  title: Text(s['name'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                  leading: const Icon(Icons.place, color: Colors.white24, size: 16),
                  onTap: () => onSelect(s),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFollowRoutePanel() {
    final legs = _selectedJourney!['legs'] as List;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF141414).withOpacity(0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Directions',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => setState(() => _selectedJourney = null),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  itemCount: legs.length,
                  itemBuilder: (context, index) {
                    final leg = legs[index];
                    return _buildLegSection(leg, index == legs.length - 1);
                  },
                ),
              ),
              const Divider(color: Colors.white12, height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Fare', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  Text(
                    'Rs. ${_selectedJourney!['total_fare']}',
                    style: const TextStyle(color: AppTheme.accentCrimson, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }

  Widget _buildLegSection(Map<String, dynamic> leg, bool isLastLeg) {
    if (leg['type'] == 'walk') {
      return _buildWalkInstruction(leg['distance_m'] ?? 0, leg['instruction'] ?? 'Walk');
    }

    final color = Color(int.parse((leg['color'] ?? '#E31C23').replaceFirst('#', '0xFF')));
    final List states = leg['stops'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.directions_bus, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leg['route_name'] ?? 'Bus',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  Text(
                    '${leg['distance_km']} km • ${leg['transport_type'] ?? 'bus'}',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...states.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final isFirst = i == 0;
          final isLast = i == states.length - 1;
          
          return _buildStopItem(
            s['name'], 
            (s['latitude'] as num).toDouble(), 
            (s['longitude'] as num).toDouble(), 
            isFirst: isFirst, 
            isLast: isLast && isLastLeg,
            lineColor: color
          );
        }).toList(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildWalkInstruction(int meters, String instruction) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(left: 20, top: 12, bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_walk, color: AppTheme.citymapperGreen, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              instruction,
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopItem(String name, double lat, double lng, {bool isFirst = false, bool isLast = false, Color lineColor = Colors.white24}) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Container(
            width: 20,
            child: Column(
              children: [
                Expanded(child: Container(width: 2, color: isFirst ? Colors.transparent : lineColor.withOpacity(0.3))),
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: isFirst || isLast ? lineColor : Colors.white24,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: isFirst || isLast ? 2 : 0),
                  ),
                ),
                Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : lineColor.withOpacity(0.3))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name, 
              style: TextStyle(
                color: isFirst || isLast ? Colors.white : Colors.white60, 
                fontSize: 14,
                fontWeight: isFirst || isLast ? FontWeight.w900 : FontWeight.normal
              )
            ),
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong, color: Colors.white24, size: 16),
            onPressed: () => _focusOnStop(lat, lng),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsPicker() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF141414).withOpacity(0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Suggestions',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final journey = _results[index];
                    return JourneyResultCard(
                      journey: journey,
                      isSelected: _selectedJourney == journey,
                      onTap: () {
                        setState(() {
                          _selectedJourney = journey;
                          _fitMapToJourney();
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _fitMapToJourney() {
    if (_selectedJourney == null) return;
    List<LatLng> points = [];
    final legs = _selectedJourney!['legs'] as List;
    for (var leg in legs) {
      if (leg['from_lat'] != null && leg['from_lng'] != null) {
        points.add(LatLng((leg['from_lat'] as num).toDouble(), (leg['from_lng'] as num).toDouble()));
      }
      if (leg['to_lat'] != null && leg['to_lng'] != null) {
        points.add(LatLng((leg['to_lat'] as num).toDouble(), (leg['to_lng'] as num).toDouble()));
      }
    }
    
    if (points.isNotEmpty) {
      var bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(100)));
    }
  }

  List<Polyline> _buildPolylines() {
    if (_selectedJourney == null) return [];
    List<Polyline> lines = [];
    final legs = _selectedJourney!['legs'] as List;
    for (var leg in legs) {
      if (leg['type'] == 'walk') continue;
      
      final List polyPoints = leg['polyline'] ?? [];
      final List<LatLng> points = polyPoints.map((p) {
        if (p is List) return LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble());
        // Sometimes JSON comes as Map with lat/lng keys
        return LatLng(
          ((p['lat'] ?? p['latitude'] ?? 0.0) as num).toDouble(), 
          ((p['lng'] ?? p['longitude'] ?? 0.0) as num).toDouble()
        );
      }).toList();

      if (points.isEmpty) {
        if (leg['from_lat'] != null && leg['from_lng'] != null) {
          points.add(LatLng((leg['from_lat'] as num).toDouble(), (leg['from_lng'] as num).toDouble()));
        }
        if (leg['to_lat'] != null && leg['to_lng'] != null) {
          points.add(LatLng((leg['to_lat'] as num).toDouble(), (leg['to_lng'] as num).toDouble()));
        }
      }

      if (points.isNotEmpty) {
        // Snap the polyline to the exact start and end stop coordinates to close any visual gaps
        final startLatLng = LatLng((leg['from_lat'] as num).toDouble(), (leg['from_lng'] as num).toDouble());
        final endLatLng = LatLng((leg['to_lat'] as num).toDouble(), (leg['to_lng'] as num).toDouble());
        
        // Only insert if it's not already exactly the same point
        if (points.first.latitude != startLatLng.latitude || points.first.longitude != startLatLng.longitude) {
          points.insert(0, startLatLng);
        }
        if (points.last.latitude != endLatLng.latitude || points.last.longitude != endLatLng.longitude) {
          points.add(endLatLng);
        }

        lines.add(Polyline(
          points: points,
          color: Color(int.parse((leg['color'] ?? '#E31C23').replaceFirst('#', '0xFF'))),
          strokeWidth: 5.0,
        ));
      }
    }
    return lines;
  }

  List<Marker> _buildMarkers() {
    List<Marker> markers = [];
    
    // Current user location
    if (_currentUserLocation != null) {
      markers.add(Marker(
        point: _currentUserLocation!,
        width: 40, height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue, width: 2),
          ),
          child: const Center(child: Icon(Icons.my_location, color: Colors.blue, size: 20)),
        ),
      ));
    }

    if (_selectedJourney != null) {
      final legs = _selectedJourney!['legs'] as List;
      
      for (int i = 0; i < legs.length; i++) {
        final leg = legs[i];
        if (leg['type'] == 'walk') continue;
        
        final color = Color(int.parse((leg['color'] ?? '#E31C23').replaceFirst('#', '0xFF')));
        final List stops = leg['stops'] ?? [];

        for (int j = 0; j < stops.length; j++) {
          final stop = stops[j];
          final isStartOfFirstLeg = i == 0 && j == 0;
          final isEndOfLastLeg = i == legs.length - 1 && j == stops.length - 1;
          
          final lat = (stop['latitude'] as num).toDouble();
          final lng = (stop['longitude'] as num).toDouble();
          
          if (isStartOfFirstLeg || isEndOfLastLeg) {
            markers.add(Marker(
              point: LatLng(lat, lng),
              width: 40, height: 40,
              alignment: Alignment.topCenter,
              child: Icon(
                isStartOfFirstLeg ? Icons.location_on : Icons.flag,
                color: isStartOfFirstLeg ? AppTheme.citymapperGreen : AppTheme.accentCrimson,
                size: 32,
              ),
            ));
          } else {
            // Intermediate stops
            markers.add(Marker(
              point: LatLng(lat, lng),
              width: 12, height: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
              ),
            ));
          }
        }
      }
    }
    
    return markers;
  }
}
