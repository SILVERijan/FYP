import 'package:flutter/material.dart';
import 'package:frontend/api_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _apiService.getAdminUsers();
      if (mounted) setState(() { _users = users; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  // ── ROLE HELPER ──────────────────────────────────────────────
  Color _roleColor(String role) {
    switch (role) {
      case 'admin': return Colors.purple;
      case 'driver': return Colors.orange;
      default: return Colors.blue;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin': return Icons.admin_panel_settings_rounded;
      case 'driver': return Icons.directions_bus_rounded;
      default: return Icons.person_outline_rounded;
    }
  }

  // ── ADD / EDIT DIALOG ────────────────────────────────────────
  void _showUserDialog({Map<String, dynamic>? user}) {
    final isEdit = user != null;
    final nameCtrl = TextEditingController(text: isEdit ? user['name'] : '');
    final emailCtrl = TextEditingController(text: isEdit ? user['email'] : '');
    final passwordCtrl = TextEditingController();
    String selectedRole = isEdit ? (user['role'] ?? 'user') : 'user';
    bool isActive = isEdit ? (user['is_active'] == true || user['is_active'] == 1) : true;
    bool obscure = true;
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
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(isEdit ? Icons.edit_rounded : Icons.person_add_rounded, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Text(isEdit ? 'Edit User' : 'Add New User', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogField(nameCtrl, 'Full Name', Icons.person_outline_rounded),
                const SizedBox(height: 14),
                _dialogField(emailCtrl, 'Email Address', Icons.email_outlined, keyboard: TextInputType.emailAddress),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscure,
                  decoration: _dialogDecoration(
                    isEdit ? 'New Password (leave blank to keep)' : 'Password',
                    Icons.lock_outline_rounded,
                    suffix: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: Colors.grey),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Role Dropdown
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: _dialogDecoration('Role', Icons.badge_outlined),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('Passenger (User)')),
                    DropdownMenuItem(value: 'driver', child: Text('Driver')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedRole = v!),
                ),
                if (isEdit) ...[
                  const SizedBox(height: 14),
                  // Active toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Icon(isActive ? Icons.check_circle_outline : Icons.cancel_outlined,
                              size: 18, color: isActive ? Colors.green : Colors.red),
                          const SizedBox(width: 8),
                          Text('Account ${isActive ? 'Active' : 'Inactive'}',
                              style: TextStyle(color: isActive ? Colors.green : Colors.red, fontWeight: FontWeight.w600)),
                        ]),
                        Switch(
                          value: isActive,
                          activeColor: Colors.green,
                          onChanged: (v) => setDialogState(() => isActive = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: saving ? null : () async {
                setDialogState(() => saving = true);
                try {
                  if (isEdit) {
                    final data = <String, dynamic>{
                      'name': nameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'role': selectedRole,
                      'is_active': isActive,
                    };
                    if (passwordCtrl.text.isNotEmpty) data['password'] = passwordCtrl.text;
                    await _apiService.updateAdminUser(user['id'], data);
                  } else {
                    await _apiService.createAdminUser({
                      'name': nameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'password': passwordCtrl.text,
                      'role': selectedRole,
                    });
                  }
                  if (mounted) Navigator.pop(ctx);
                  _fetchUsers();
                } catch (e) {
                  setDialogState(() => saving = false);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isEdit ? 'Save Changes' : 'Create User'),
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
        title: const Text('Delete User', style: TextStyle(fontWeight: FontWeight.bold)),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: '? This action cannot be undone.'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _apiService.deleteAdminUser(id);
              _fetchUsers();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── DIALOG HELPERS ───────────────────────────────────────────
  InputDecoration _dialogDecoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: Colors.red),
      suffixIcon: suffix,
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
                    const Text('User Management', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('${_users.length} user${_users.length != 1 ? 's' : ''} registered', style: const TextStyle(fontSize: 16, color: Colors.white70)),
                  ]),
                  ElevatedButton.icon(
                    onPressed: () => _showUserDialog(),
                    icon: const Icon(Icons.person_add_rounded),
                    label: const Text('Add New User'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red[800], padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  ),
                ],
              ),
            ),

            // User List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.red))
                  : _users.isEmpty
                      ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No users found', style: TextStyle(color: Colors.grey, fontSize: 16)),
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
                              itemCount: _users.length,
                              separatorBuilder: (_, __) => Divider(color: Colors.grey[100], height: 1),
                              itemBuilder: (context, index) {
                                final user = _users[index];
                                final String role = user['role'] ?? 'user';
                                final bool active = user['is_active'] == true || user['is_active'] == 1;
                                final Color roleColor = _roleColor(role);

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  leading: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: roleColor.withValues(alpha: 0.1),
                                        backgroundImage: user['profile_picture'] != null && user['profile_picture'].toString().isNotEmpty
                                            ? NetworkImage(_apiService.getProfileImageUrl(user['profile_picture']))
                                            : null,
                                        child: (user['profile_picture'] == null || user['profile_picture'].toString().isEmpty)
                                            ? Text(user['name'][0].toUpperCase(), style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 16))
                                            : null,
                                      ),
                                      if (!active)
                                        Positioned(
                                          right: 0, bottom: 0,
                                          child: Container(
                                            width: 12, height: 12,
                                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                          ),
                                        )
                                      else
                                        Positioned(
                                          right: 0, bottom: 0,
                                          child: Container(
                                            width: 12, height: 12,
                                            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                          ),
                                        ),
                                    ],
                                  ),
                                  title: Row(children: [
                                    Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(width: 8),
                                    if (!active)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                        child: const Text('Inactive', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                  ]),
                                  subtitle: Text(user['email'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  trailing: SizedBox(
                                    width: 220,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // Role Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            Icon(_roleIcon(role), size: 12, color: roleColor),
                                            const SizedBox(width: 4),
                                            Text(role.toUpperCase(), style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 10)),
                                          ]),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blueGrey),
                                          tooltip: 'Edit',
                                          onPressed: () => _showUserDialog(user: user),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                                          tooltip: 'Delete',
                                          onPressed: () => _showDeleteDialog(user['id'], user['name']),
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
