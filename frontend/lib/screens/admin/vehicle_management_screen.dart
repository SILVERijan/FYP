import 'package:flutter/material.dart';
import 'package:frontend/api_service.dart';

class VehicleManagementScreen extends StatefulWidget {
  const VehicleManagementScreen({super.key});

  @override
  State<VehicleManagementScreen> createState() => _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _vehicles = [];
  List<dynamic> _routes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getAdminVehicles(),
        _apiService.getAdminRoutes(),
      ]);
      if (mounted) {
        setState(() {
          _vehicles = results[0];
          _routes = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  // ── ADD / EDIT DIALOG ────────────────────────────────────────
  void _showVehicleDialog({Map<String, dynamic>? vehicle}) {
    final isEdit = vehicle != null;

    final nameCtrl = TextEditingController(text: isEdit ? (vehicle['vehicle_name'] ?? '') : '');
    final plateCtrl = TextEditingController(text: isEdit ? (vehicle['plate_number'] ?? '') : '');
    final capacityCtrl = TextEditingController(text: isEdit && vehicle['capacity'] != null ? vehicle['capacity'].toString() : '');

    String selectedType = isEdit ? (vehicle['type'] ?? 'Bus') : 'Bus';
    String selectedStatus = isEdit ? (vehicle['status'] ?? 'active') : 'active';

    // Pre-select route
    dynamic selectedRouteId;
    if (isEdit && vehicle['route'] != null) {
      selectedRouteId = vehicle['route']['id'];
    } else if (_routes.isNotEmpty) {
      selectedRouteId = _routes[0]['id'];
    }

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
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(isEdit ? Icons.edit_rounded : Icons.directions_bus_rounded, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Text(isEdit ? 'Edit Vehicle' : 'Add New Vehicle', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Vehicle Name
                  _dialogField(nameCtrl, 'Vehicle Name', Icons.directions_bus_outlined),
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
                  const SizedBox(height: 14),
                  // Plate Number
                  _dialogField(plateCtrl, 'Plate Number', Icons.pin_outlined),
                  const SizedBox(height: 14),
                  // Route Selector
                  DropdownButtonFormField<dynamic>(
                    value: selectedRouteId,
                    decoration: _dialogDecoration('Assigned Route', Icons.route_outlined),
                    isExpanded: true,
                    items: _routes.map((route) {
                      return DropdownMenuItem(
                        value: route['id'],
                        child: Text(
                          route['name'] ?? route['route_name'] ?? 'Route #${route['id']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(() => selectedRouteId = v),
                  ),
                  const SizedBox(height: 14),
                  // Capacity
                  _dialogField(capacityCtrl, 'Capacity (optional)', Icons.people_outline_rounded, keyboard: TextInputType.number),
                  const SizedBox(height: 14),
                  // Status
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: _dialogDecoration('Status', Icons.toggle_on_outlined),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('✅ Active')),
                      DropdownMenuItem(value: 'inactive', child: Text('❌ Inactive')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedStatus = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: saving ? null : () async {
                if (nameCtrl.text.trim().isEmpty || plateCtrl.text.trim().isEmpty || selectedRouteId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all required fields')));
                  return;
                }
                setDialogState(() => saving = true);
                try {
                  final data = {
                    'vehicle_name': nameCtrl.text.trim(),
                    'type': selectedType,
                    'plate_number': plateCtrl.text.trim(),
                    'route_id': selectedRouteId,
                    'status': selectedStatus,
                    if (capacityCtrl.text.isNotEmpty) 'capacity': int.tryParse(capacityCtrl.text),
                  };
                  if (isEdit) {
                    await _apiService.updateAdminVehicle(vehicle['id'], data);
                  } else {
                    await _apiService.createAdminVehicle(data);
                  }
                  if (mounted) Navigator.pop(ctx);
                  _fetchData();
                } catch (e) {
                  setDialogState(() => saving = false);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isEdit ? 'Save Changes' : 'Add Vehicle'),
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
        title: const Text('Delete Vehicle', style: TextStyle(fontWeight: FontWeight.bold)),
        content: RichText(text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            const TextSpan(text: 'Are you sure you want to delete '),
            TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(text: '?'),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _apiService.deleteAdminVehicle(id);
              _fetchData();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── DIALOG HELPERS ───────────────────────────────────────────
  InputDecoration _dialogDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: Colors.red),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label, IconData icon, {TextInputType? keyboard}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: _dialogDecoration(label, icon),
    );
  }

  // ── TYPE COLOR ───────────────────────────────────────────────
  Color _typeColor(String? type) {
    switch (type) {
      case 'Bus': return Colors.blue;
      case 'Micro': return Colors.teal;
      case 'Tempo': return Colors.purple;
      case 'Minibus': return Colors.indigo;
      default: return Colors.grey;
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
                    const Text('Transport Management', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('${_vehicles.length} vehicle${_vehicles.length != 1 ? 's' : ''} registered', style: const TextStyle(fontSize: 16, color: Colors.white70)),
                  ]),
                  ElevatedButton.icon(
                    onPressed: () => _showVehicleDialog(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Vehicle'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red[800], padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  ),
                ],
              ),
            ),

            // Vehicle List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.red))
                  : _vehicles.isEmpty
                      ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.directions_bus_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No vehicles found', style: TextStyle(color: Colors.grey, fontSize: 16)),
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
                              itemCount: _vehicles.length,
                              separatorBuilder: (_, __) => Divider(color: Colors.grey[100], height: 1),
                              itemBuilder: (context, index) {
                                final vehicle = _vehicles[index];
                                final String type = vehicle['type'] ?? 'Bus';
                                final bool isActive = vehicle['status'] == 'active';
                                final String vehicleName = vehicle['vehicle_name'] ?? vehicle['plate_number'] ?? 'Vehicle #${vehicle['id']}';
                                final String routeName = vehicle['route'] != null
                                    ? (vehicle['route']['name'] ?? vehicle['route']['route_name'] ?? 'Unknown Route')
                                    : 'No Route';

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  leading: Container(
                                    width: 48, height: 48,
                                    decoration: BoxDecoration(color: _typeColor(type).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                    child: Icon(Icons.directions_bus_rounded, color: _typeColor(type)),
                                  ),
                                  title: Text(vehicleName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text('Plate: ${vehicle['plate_number']} • $type', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  trailing: SizedBox(
                                    width: 280,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // Route badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            const Icon(Icons.route_rounded, size: 12, color: Colors.green),
                                            const SizedBox(width: 4),
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 100),
                                              child: Text(routeName, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10), overflow: TextOverflow.ellipsis),
                                            ),
                                          ]),
                                        ),
                                        const SizedBox(width: 6),
                                        // Status badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(isActive ? 'Active' : 'Inactive',
                                            style: TextStyle(color: isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blueGrey),
                                          tooltip: 'Edit',
                                          onPressed: () => _showVehicleDialog(vehicle: vehicle),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                                          tooltip: 'Delete',
                                          onPressed: () => _showDeleteDialog(vehicle['id'], vehicleName),
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
