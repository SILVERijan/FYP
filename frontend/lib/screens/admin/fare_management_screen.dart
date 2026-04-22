import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../api_service.dart';
import '../../theme/app_theme.dart';

class AdminFareManagementScreen extends StatefulWidget {
  const AdminFareManagementScreen({super.key});

  @override
  State<AdminFareManagementScreen> createState() => _AdminFareManagementScreenState();
}

class _AdminFareManagementScreenState extends State<AdminFareManagementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _fareRules = [];
  List<dynamic> _routes = [];
  bool _isLoading = true;

  final List<String> _vehicleTypes = ['Bus', 'Micro Bus', 'Tempo', 'Safa Tempo'];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getAdminFareRules(),
        _apiService.getAdminRoutes(page: 1), // Fetch first page of routes for the dropdown
      ]);
      setState(() {
        _fareRules = results[0] as List<dynamic>;
        _routes = (results[1] as Map<String, dynamic>)['data'] ?? [];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRule(int id) async {
    try {
      await _apiService.deleteAdminFareRule(id);
      _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting rule: $e')),
        );
      }
    }
  }

  void _showAddEditDialog([Map<String, dynamic>? rule]) {
    final minController = TextEditingController(text: rule?['min_km']?.toString() ?? '');
    final maxController = TextEditingController(text: rule?['max_km']?.toString() ?? '');
    final fareController = TextEditingController(text: rule?['fare']?.toString() ?? '');
    bool isActive = rule?['is_active'] ?? true;
    String? vehicleType = rule?['vehicle_type'];
    int? routeId = rule?['route_id'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 32,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.primaryWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule == null ? 'Add Pricing Rule' : 'Edit Pricing Rule',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minController,
                        decoration: const InputDecoration(labelText: 'Min KM'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: maxController,
                        decoration: const InputDecoration(labelText: 'Max KM (Optional)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: fareController,
                  decoration: const InputDecoration(
                    labelText: 'Fare Amount (NRs)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Vehicle Type (Optional)'),
                  value: vehicleType,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Types')),
                    ..._vehicleTypes.map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  ],
                  onChanged: (val) => setDialogState(() => vehicleType = val),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Specific Route (Optional)'),
                  value: routeId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Routes')),
                    ..._routes.map((r) => DropdownMenuItem<int>(
                          value: r['id'],
                          child: Text(r['name'].toString().length > 25 
                              ? '${r['name'].toString().substring(0, 25)}...' 
                              : r['name']),
                        ))
                  ],
                  onChanged: (val) => setDialogState(() => routeId = val),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Rule is Active', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: isActive,
                  activeColor: AppTheme.accentCrimson,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setDialogState(() => isActive = val),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    final data = {
                      'min_km': double.tryParse(minController.text) ?? 0,
                      'max_km': maxController.text.isEmpty ? null : double.tryParse(maxController.text),
                      'fare': double.tryParse(fareController.text) ?? 0,
                      'is_active': isActive,
                      'vehicle_type': vehicleType,
                      'route_id': routeId,
                    };

                    try {
                      if (rule == null) {
                        await _apiService.createAdminFareRule(data);
                      } else {
                        await _apiService.updateAdminFareRule(rule['id'], data);
                      }
                      if (context.mounted) Navigator.pop(context);
                      _fetchData();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error saving: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save Pricing Rule'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutralGrey,
      appBar: AppBar(
        title: const Text('Pricing & Fares'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCrimson))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryBlack,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Rules',
                        style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_fareRules.length} Configurations',
                        style: const TextStyle(
                          color: AppTheme.primaryWhite,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ).animate().fadeIn().slideY(begin: 0.2),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _fareRules.length,
                    itemBuilder: (context, index) {
                      final rule = _fareRules[index];
                      final range = rule['max_km'] == null
                          ? '${rule['min_km']}+ KM'
                          : '${rule['min_km']} - ${rule['max_km']} KM';

                      String subtitle = '';
                      if (rule['route'] != null) subtitle += 'Route: ${rule['route']['name']}';
                      if (rule['vehicle_type'] != null) {
                        if (subtitle.isNotEmpty) subtitle += ' • ';
                        subtitle += '${rule['vehicle_type']}';
                      }
                      if (subtitle.isEmpty) subtitle = 'General Distance Rule';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryWhite,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          title: Row(
                            children: [
                              Text(range, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                              const SizedBox(width: 8),
                              if (!rule['is_active'])
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('INACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                )
                            ],
                          ),
                          subtitle: Text(subtitle, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black45)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('NRs ${rule['fare']}', style: const TextStyle(color: AppTheme.accentCrimson, fontWeight: FontWeight.w900, fontSize: 20)),
                            ],
                          ),
                          onTap: () => _showAddEditDialog(rule),
                          onLongPress: () => _deleteRule(rule['id']),
                        ),
                      ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX(begin: 0.1);
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppTheme.accentCrimson,
        icon: const Icon(Icons.add, color: AppTheme.primaryWhite),
        label: const Text('New Rule', style: TextStyle(color: AppTheme.primaryWhite, fontWeight: FontWeight.bold)),
      ).animate().scale(delay: 400.ms),
    );
  }
}
