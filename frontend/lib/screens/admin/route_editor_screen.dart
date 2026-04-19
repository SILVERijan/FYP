import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api_service.dart';
import '../../models/transport_route.dart';

class RouteEditorScreen extends StatefulWidget {
  final TransportRoute? route;
  const RouteEditorScreen({super.key, this.route});

  @override
  State<RouteEditorScreen> createState() => _RouteEditorScreenState();
}

class _RouteEditorScreenState extends State<RouteEditorScreen> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();
  final TextEditingController _nameController = TextEditingController();
  
  String _selectedType = 'Bus';
  Color _selectedColor = Colors.red;
  List<LatLng> _stops = [];
  List<LatLng> _polylinePoints = [];
  bool _isProcessing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.route != null) {
      _nameController.text = widget.route!.name;
      _selectedType = widget.route!.type;
      _selectedColor = _parseHexColor(widget.route!.color);
      if (widget.route!.stops != null) {
        _stops = widget.route!.stops!.map((s) => LatLng(s.latitude, s.longitude)).toList();
      }
      if (widget.route!.polyline != null) {
        _polylinePoints = widget.route!.polyline!.map((p) => LatLng(p[0], p[1])).toList();
      }
    }
  }

  Color _parseHexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.red;
    }
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  Future<void> _fetchOSRMRoute(LatLng start, LatLng end) async {
    setState(() => _isProcessing = true);
    final url = 'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok') {
          final List coords = data['routes'][0]['geometry']['coordinates'];
          final newPoints = coords.map((c) => LatLng(c[1], c[0])).toList();
          setState(() {
            _polylinePoints.addAll(newPoints);
          });
        }
      }
    } catch (e) {
      debugPrint('OSRM Error: $e');
      // Fallback: straight line
      setState(() {
        _polylinePoints.add(end);
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _handleTap(TapPosition tapPosition, LatLng point) async {
    setState(() {
      _stops.add(point);
    });

    if (_stops.length == 1) {
      setState(() {
        _polylinePoints.add(point);
      });
    } else {
      await _fetchOSRMRoute(_stops[_stops.length - 2], point);
    }
  }

  void _undoLastStop() {
    if (_stops.isNotEmpty) {
      setState(() {
        _stops.removeLast();
        _rebuildPolyline();
      });
    }
  }

  Future<void> _rebuildPolyline() async {
    if (_stops.isEmpty) {
      setState(() => _polylinePoints = []);
      return;
    }
    
    List<LatLng> newPoly = [_stops.first];
    setState(() {
      _polylinePoints = newPoly;
      _isProcessing = true;
    });

    for (int i = 0; i < _stops.length - 1; i++) {
      await _fetchOSRMRoute(_stops[i], _stops[i+1]);
    }
    
    setState(() => _isProcessing = false);
  }

  Future<void> _saveRoute() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter route name')));
      return;
    }
    if (_stops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one stop')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final routeData = {
        'name': _nameController.text,
        'type': _selectedType,
        'color': _colorToHex(_selectedColor),
        'polyline': _polylinePoints.map((p) => [p.latitude, p.longitude]).toList(),
        'stops': _stops.map((s) => {
          'name': 'Stop ${_stops.indexOf(s) + 1}',
          'latitude': s.latitude,
          'longitude': s.longitude
        }).toList(),
      };

      if (widget.route != null) {
        await _apiService.updateAdminRoute(widget.route!.id, routeData);
      } else {
        await _apiService.createAdminRoute(routeData);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.route == null ? 'Add New Route' : 'Edit Route', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        actions: [
          if (_isProcessing)
            const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
        ],
      ),
      body: Column(
        children: [
          // Editor Controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Route Name',
                          hintText: 'e.g. Ratnapark - Gongabu',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.label_important_outline),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: _selectedColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _selectedColor.withOpacity(0.3)),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.color_lens, color: _selectedColor),
                        onPressed: _showColorPicker,
                        tooltip: 'Select Color',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: InputDecoration(
                          labelText: 'Transport Type',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.directions_bus_outlined),
                        ),
                        items: ['Bus', 'Micro', 'Tempo', 'Minibus'].map((String value) {
                          return DropdownMenuItem<String>(value: value, child: Text(value));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedType = val!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _undoLastStop,
                      icon: const Icon(Icons.undo),
                      label: const Text('Undo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Map
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(27.7000, 85.3000),
                    initialZoom: 13.0,
                    onTap: _handleTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.frontend',
                    ),
                    if (_polylinePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _polylinePoints,
                            color: _selectedColor,
                            strokeWidth: 5.0,
                          ),
                        ],
                      ),
                    if (_stops.isNotEmpty)
                      MarkerLayer(
                        markers: _stops.asMap().entries.map((entry) {
                          int idx = entry.key;
                          LatLng point = entry.value;
                          return Marker(
                            point: point,
                            width: 30,
                            height: 30,
                            child: Container(
                              decoration: BoxDecoration(
                                color: idx == 0 ? Colors.green : (idx == _stops.length - 1 ? Colors.red : Colors.orange),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: Center(
                                child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Instruction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const Text('Tap map to add stops', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_stops.length} Stops Added', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${_polylinePoints.length} Polyline Points', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 150,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveRoute,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save Route', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick Route Color'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: _selectedColor,
              onColorChanged: (color) {
                setState(() => _selectedColor = color);
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      },
    );
  }
}
