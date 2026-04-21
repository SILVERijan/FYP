import 'package:flutter/material.dart';
import '../../api_service.dart';

class AdminFareManagementScreen extends StatefulWidget {
  const AdminFareManagementScreen({super.key});

  @override
  State<AdminFareManagementScreen> createState() => _AdminFareManagementScreenState();
}

class _AdminFareManagementScreenState extends State<AdminFareManagementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _fareRules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFareRules();
  }

  Future<void> _fetchFareRules() async {
    setState(() => _isLoading = true);
    try {
      final rules = await _apiService.getAdminFareRules();
      setState(() => _fareRules = rules);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching fare rules: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRule(int id) async {
    try {
      await _apiService.deleteAdminFareRule(id);
      _fetchFareRules();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting rule: $e')),
      );
    }
  }

  void _showAddEditDialog([Map<String, dynamic>? rule]) {
    final minController = TextEditingController(text: rule?['min_km']?.toString() ?? '');
    final maxController = TextEditingController(text: rule?['max_km']?.toString() ?? '');
    final fareController = TextEditingController(text: rule?['fare']?.toString() ?? '');
    bool isActive = rule?['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(rule == null ? 'Add Fare Rule' : 'Edit Fare Rule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: minController,
                  decoration: const InputDecoration(labelText: 'Min KM'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: maxController,
                  decoration: const InputDecoration(labelText: 'Max KM (Leave empty for more than X km)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: fareController,
                  decoration: const InputDecoration(labelText: 'Fare Amount (NPR)'),
                  keyboardType: TextInputType.number,
                ),
                SwitchListTile(
                  title: const Text('Is Active'),
                  value: isActive,
                  onChanged: (val) => setDialogState(() => isActive = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'min_km': double.tryParse(minController.text) ?? 0,
                  'max_km': maxController.text.isEmpty ? null : double.tryParse(maxController.text),
                  'fare': double.tryParse(fareController.text) ?? 0,
                  'is_active': isActive,
                };

                try {
                  if (rule == null) {
                    await _apiService.createAdminFareRule(data);
                  } else {
                    await _apiService.updateAdminFareRule(rule['id'], data);
                  }
                  Navigator.pop(context);
                  _fetchFareRules();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fare Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _fareRules.length,
              itemBuilder: (context, index) {
                final rule = _fareRules[index];
                final range = rule['max_km'] == null 
                  ? 'More than ${rule['min_km']} KM'
                  : '${rule['min_km']} - ${rule['max_km']} KM';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    title: Text(range, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    subtitle: Text('Fare: NRs. ${rule['fare']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showAddEditDialog(rule)),
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteRule(rule['id'])),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
