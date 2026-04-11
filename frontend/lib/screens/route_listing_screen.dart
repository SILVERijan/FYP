import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/transport_route.dart';
import '../api_service.dart';
import 'map_tracking_screen.dart';
import '../theme/app_theme.dart';

class RouteListingScreen extends StatefulWidget {
  final bool showAppBar;
  final Function(TransportRoute)? onRouteSelected;
  const RouteListingScreen({super.key, this.showAppBar = true, this.onRouteSelected});

  @override
  State<RouteListingScreen> createState() => _RouteListingScreenState();
}

class _RouteListingScreenState extends State<RouteListingScreen> {
  final ApiService _apiService = ApiService();
  List<TransportRoute> _allRoutes = [];
  List<TransportRoute> _filteredRoutes = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
  }

  Future<void> _fetchRoutes() async {
    try {
      final routes = await _apiService.getRoutes();
      setState(() {
        _allRoutes = routes;
        _filteredRoutes = routes;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterRoutes(String query) {
    setState(() {
      _filteredRoutes = _allRoutes
          .where((r) => r.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.showAppBar ? AppBar(
        title: const Text('All Routes'),
        elevation: 0,
      ) : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.showAppBar)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text('Transit Routes', style: theme.textTheme.displayLarge?.copyWith(fontSize: 28)),
              ).animate().fadeIn().slideX(begin: -0.1),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: TextField(
                controller: _searchController,
                onChanged: _filterRoutes,
                decoration: InputDecoration(
                  hintText: 'Search for a route...',
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.black54),
                  hintStyle: const TextStyle(color: Colors.black26),
                  filled: true,
                  fillColor: AppTheme.neutralGrey.withOpacity(0.5),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ).animate().fadeIn(delay: 100.ms),
            
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : _filteredRoutes.isEmpty
                  ? const Center(child: Text('No routes found', style: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold)))
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: _filteredRoutes.length,
                      itemBuilder: (context, index) {
                        final route = _filteredRoutes[index];
                        return _buildRouteItem(route, theme)
                          .animate()
                          .fadeIn(delay: (index * 50).ms, duration: 400.ms)
                          .slideX(begin: 0.05);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteItem(TransportRoute route, ThemeData theme) {
    // Dynamic color coding based on route type (Citymapper style)
    Color typeColor = Colors.black;
    if (route.type.toLowerCase().contains('bus')) typeColor = AppTheme.accentCrimson;
    if (route.type.toLowerCase().contains('micro')) typeColor = Colors.blueAccent;
    if (route.type.toLowerCase().contains('express')) typeColor = Colors.deepPurple;

    return GestureDetector(
      onTap: () {
        if (widget.onRouteSelected != null) {
          widget.onRouteSelected!(route);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MapTrackingScreen(route: route)),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.neutralGrey),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    route.type.toLowerCase().contains('bus') ? Icons.directions_bus_rounded : Icons.airport_shuttle_rounded, 
                    color: typeColor, 
                    size: 24
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            route.type.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Real-time tracking',
                          style: TextStyle(color: Colors.black38, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.black12),
            ],
          ),
        ),
      ),
    );
  }
}
