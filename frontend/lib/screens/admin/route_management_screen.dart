import 'package:flutter/material.dart';
import 'package:frontend/api_service.dart';
import 'package:frontend/models/transport_route.dart';
import 'package:frontend/screens/admin/route_editor_screen.dart';

class RouteManagementScreen extends StatefulWidget {
  const RouteManagementScreen({super.key});

  @override
  State<RouteManagementScreen> createState() => _RouteManagementScreenState();
}

class _RouteManagementScreenState extends State<RouteManagementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _routes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
  }

  Future<void> _fetchRoutes() async {
    setState(() => _isLoading = true);
    try {
      final routes = await _apiService.getAdminRoutes();
      if (mounted) setState(() { _routes = routes; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  // ── NAVIGATE TO EDITOR ────────────────────────────────────────
  void _navigateToEditor({Map<String, dynamic>? routeData}) async {
    TransportRoute? route;
    if (routeData != null) {
      route = TransportRoute.fromJson(routeData);
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteEditorScreen(route: route),
      ),
    );

    if (result == true) {
      _fetchRoutes();
    }
  }

  // ── DELETE DIALOG ────────────────────────────────────────────
  void _showDeleteDialog(int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Route', style: TextStyle(fontWeight: FontWeight.bold)),
        content: RichText(text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            const TextSpan(text: 'Are you sure you want to delete route '),
            TextSpan(text: '"$name"', style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(text: '? All assigned vehicles will be affected.'),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _apiService.deleteAdminRoute(id);
              _fetchRoutes();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }



  Color _getRouteColor(dynamic route) {
    if (route['color'] != null) {
      try {
        return Color(int.parse(route['color'].toString().replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return _typeColor(route['type']);
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'Bus': return Colors.blue;
      case 'Micro': return Colors.teal;
      case 'Tempo': return Colors.purple;
      case 'Minibus': return Colors.indigo;
      default: return Colors.orange;
    }
  }

  // ── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Theme.of(context).colorScheme.primary, Colors.red[800]!],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 12,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Route Management', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('${_routes.length} route${_routes.length != 1 ? 's' : ''} configured', style: const TextStyle(fontSize: 16, color: Colors.white70)),
                  ]),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToEditor(),
                    icon: const Icon(Icons.add_location_alt_rounded),
                    label: const Text('Design Route'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red[800], padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  ),
                ],
              ),
            ),

            // Route List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.red))
                  : _routes.isEmpty
                      ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.route_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No routes found', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ]))
                      : Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: ListView.separated(
                              itemCount: _routes.length,
                              separatorBuilder: (_, __) => Divider(color: Colors.grey[100], height: 1),
                              itemBuilder: (context, index) {
                                final route = _routes[index];
                                // Support both 'name' and 'route_name' field names
                                final String routeName = route['name'] ?? route['route_name'] ?? 'Unnamed Route';
                                final String routeType = route['type'] ?? 'Bus';

                                  final Color routeColor = _getRouteColor(route);
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    leading: Container(
                                      width: 48, height: 48,
                                      decoration: BoxDecoration(color: routeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                      child: Icon(Icons.route_rounded, color: routeColor),
                                    ),
                                  title: Text(routeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text('ID: ${route['id']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  trailing: SizedBox(
                                    width: 200,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // Type Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(color: _typeColor(routeType).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                          child: Text(routeType, style: TextStyle(color: _typeColor(routeType), fontWeight: FontWeight.bold, fontSize: 11)),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.edit_location_alt_outlined, size: 20, color: Colors.blueGrey),
                                          tooltip: 'Edit Geometry',
                                          onPressed: () => _navigateToEditor(routeData: route),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                                          tooltip: 'Delete',
                                          onPressed: () => _showDeleteDialog(route['id'], routeName),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
