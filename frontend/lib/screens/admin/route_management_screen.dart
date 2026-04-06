import 'package:flutter/material.dart';
import 'package:frontend/api_service.dart';

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

  // ── ADD / EDIT DIALOG ────────────────────────────────────────
  void _showRouteDialog({Map<String, dynamic>? route}) {
    final isEdit = route != null;
    // Support both 'name' and 'route_name' keys
    final nameCtrl = TextEditingController(text: isEdit ? (route['name'] ?? route['route_name'] ?? '') : '');
    String selectedType = isEdit ? (route['type'] ?? 'Bus') : 'Bus';
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(isEdit ? Icons.edit_road_rounded : Icons.add_road_rounded, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              Text(isEdit ? 'Edit Route' : 'Add New Route', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Route Name
              TextField(
                controller: nameCtrl,
                decoration: _dialogDecoration('Route Name (e.g. Ratnapark - Kalanki)', Icons.label_outline_rounded),
              ),
              const SizedBox(height: 14),
              // Transport Type
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: _dialogDecoration('Transport Type', Icons.category_outlined),
                items: const [
                  DropdownMenuItem(value: 'Bus', child: Text('🚌 Bus')),
                  DropdownMenuItem(value: 'Micro', child: Text('🚐 Micro')),
                  DropdownMenuItem(value: 'Tempo', child: Text('🛺 Tempo')),
                  DropdownMenuItem(value: 'Minibus', child: Text('🚍 Minibus')),
                ],
                onChanged: (v) => setDialogState(() => selectedType = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: saving ? null : () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Route name is required')));
                  return;
                }
                setDialogState(() => saving = true);
                try {
                  final data = {'name': nameCtrl.text.trim(), 'type': selectedType};
                  if (isEdit) {
                    await _apiService.updateAdminRoute(route['id'], data);
                  } else {
                    await _apiService.createAdminRoute(data);
                  }
                  if (mounted) Navigator.pop(ctx);
                  _fetchRoutes();
                } catch (e) {
                  setDialogState(() => saving = false);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isEdit ? 'Save Changes' : 'Add Route'),
            ),
          ],
        );
      }),
    );
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

  InputDecoration _dialogDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: Colors.orange),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.orange, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
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
                    onPressed: () => _showRouteDialog(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Route'),
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

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  leading: Container(
                                    width: 48, height: 48,
                                    decoration: BoxDecoration(color: _typeColor(routeType).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                    child: Icon(Icons.route_rounded, color: _typeColor(routeType)),
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
                                          icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blueGrey),
                                          tooltip: 'Edit',
                                          onPressed: () => _showRouteDialog(route: route),
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
