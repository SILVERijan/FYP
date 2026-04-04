import 'package:flutter/material.dart';
import 'package:frontend/models/transport_route.dart';
import 'package:frontend/screens/route_listing_screen.dart';
import 'package:frontend/screens/map_tracking_screen.dart';

class DesktopRoutesDashboard extends StatefulWidget {
  const DesktopRoutesDashboard({super.key});

  @override
  State<DesktopRoutesDashboard> createState() => _DesktopRoutesDashboardState();
}

class _DesktopRoutesDashboardState extends State<DesktopRoutesDashboard> {
  TransportRoute? _selectedRoute;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Master Panel containing the Route Listing
        Container(
          width: 350,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.grey.shade300, width: 1)),
          ),
          child: RouteListingScreen(
            showAppBar: false,
            onRouteSelected: (route) {
              setState(() {
                _selectedRoute = route;
              });
            },
          ),
        ),
        
        // Detail Panel containing the Map Tracking Screen
        Expanded(
          child: _selectedRoute == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 80, color: Colors.black26),
                      SizedBox(height: 16),
                      Text(
                        "Select a route from the list to view its map",
                        style: TextStyle(fontSize: 18, color: Colors.black54),
                      )
                    ],
                  ),
                )
              : MapTrackingScreen(
                  key: ValueKey(_selectedRoute!.id), // Ensure full widget rebuild when route changes
                  route: _selectedRoute,
                  showAppBar: false,
                ),
        ),
      ],
    );
  }
}
