import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/search_result_card.dart';
import 'map_tracking_screen.dart';
import '../models/transport_route.dart';

class RouteSearchScreen extends StatefulWidget {
  final bool asFragment;
  const RouteSearchScreen({super.key, this.asFragment = false});

  @override
  State<RouteSearchScreen> createState() => _RouteSearchScreenState();
}

class _RouteSearchScreenState extends State<RouteSearchScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destController = TextEditingController();
  
  List<Map<String, dynamic>> _startSuggestions = [];
  List<Map<String, dynamic>> _destSuggestions = [];
  
  Map<String, dynamic>? _selectedStart;
  Map<String, dynamic>? _selectedDest;
  
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _isSearching = false;

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

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition();
        setState(() {
          _selectedStart = {
            'name': 'Current Location',
            'latitude': position.latitude,
            'longitude': position.longitude,
          };
          _startController.text = 'Current Location';
          _startSuggestions = [];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
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
          const SnackBar(content: Text('No routes found between these locations even with transfers.')),
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

  @override
  Widget build(BuildContext context) {
    if (widget.asFragment) {
      return Column(
        children: [
          _buildSearchBox(),
          if (_isSearching)
            const LinearProgressIndicator(color: Colors.black, backgroundColor: Colors.transparent),
          Expanded(
            child: _results.isEmpty && !_isSearching
                ? _buildEmptyState()
                : _buildResultsList(),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Plan Journey',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBox(),
          if (_isSearching)
            const LinearProgressIndicator(color: Colors.black, backgroundColor: Colors.transparent),
          Expanded(
            child: _results.isEmpty && !_isSearching
                ? _buildEmptyState()
                : _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          _buildInput(
            controller: _startController,
            hint: 'Starting point',
            icon: Icons.my_location_rounded,
            onChanged: (val) => _getSuggestions(val, true),
            suggestions: _startSuggestions,
            onSelect: (stop) {
              setState(() {
                _selectedStart = stop;
                _startController.text = stop['name'];
                _startSuggestions = [];
              });
            },
            trailing: IconButton(
              icon: const Icon(Icons.gps_fixed_rounded, size: 20),
              onPressed: _useCurrentLocation,
            ),
          ),
          const SizedBox(height: 12),
          _buildInput(
            controller: _destController,
            hint: 'Where to?',
            icon: Icons.location_on_rounded,
            onChanged: (val) => _getSuggestions(val, false),
            suggestions: _destSuggestions,
            onSelect: (stop) {
              setState(() {
                _selectedDest = stop;
                _destController.text = stop['name'];
                _destSuggestions = [];
              });
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _searchRoutes,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Find Routes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Function(String) onChanged,
    required List<Map<String, dynamic>> suggestions,
    required Function(Map<String, dynamic>) onSelect,
    Widget? trailing,
  }) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.neutralGrey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: Colors.black45, size: 20),
              suffixIcon: trailing,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final stop = suggestions[index];
                return ListTile(
                  title: Text(stop['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => onSelect(stop),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_bus_rounded, size: 80, color: Colors.black.withOpacity(0.05)),
          const SizedBox(height: 16),
          const Text(
            'Enter locations to find bus routes\nand estimate fares.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        return SearchResultCard(
          result: result,
          onTap: () {
            // Future: Better way to transition, for now just show map
             Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MapTrackingScreen(
                  searchedJourney: result['legs'],
                  showAppBar: false,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
