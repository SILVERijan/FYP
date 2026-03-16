import 'package:flutter/material.dart';
import '../models/transport_route.dart';
import '../api_service.dart';
import 'map_tracking_screen.dart';

class RouteListingScreen extends StatefulWidget {
  const RouteListingScreen({super.key});

  @override
  State<RouteListingScreen> createState() => _RouteListingScreenState();
}

class _RouteListingScreenState extends State<RouteListingScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<TransportRoute>> _routesFuture;

  @override
  void initState() {
    super.initState();
    _routesFuture = _apiService.getRoutes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transport Routes'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<TransportRoute>>(
        future: _routesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No routes found.'));
          }

          final routes = snapshot.data!;
          return ListView.builder(
            itemCount: routes.length,
            itemBuilder: (context, index) {
              final route = routes[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.directions_bus, color: Colors.deepPurple, size: 32),
                  title: Text(route.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(route.type),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MapTrackingScreen(route: route),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
