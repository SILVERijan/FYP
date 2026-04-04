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
    try {
      final users = await _apiService.getAdminUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDeleteDialog(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _apiService.deleteAdminUser(id);
              _fetchUsers();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // App theme background
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
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('User Management', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text('Control user access, roles, and assignments.', style: TextStyle(fontSize: 16, color: Colors.white70)),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add New User coming soon')));
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add New User'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red[800]),
                  )
                ],
              ),
            ),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.red))
                : Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: ListView.separated(
                        itemCount: _users.length,
                        separatorBuilder: (context, index) => Divider(color: Colors.grey[200], height: 1),
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final bool isAdmin = user['role'] == 'admin';
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey[200],
                              backgroundImage: user['profile_picture'] != null && user['profile_picture'].toString().isNotEmpty ? NetworkImage(_apiService.getProfileImageUrl(user['profile_picture'])) : null,
                              child: user['profile_picture'] == null || user['profile_picture'].toString().isEmpty ? Text(user['name'][0].toUpperCase(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)) : null,
                            ),
                            title: Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(user['email'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            trailing: SizedBox(
                              width: 200,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Role Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isAdmin ? Colors.purple.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(isAdmin ? Icons.admin_panel_settings : Icons.person_outline, size: 14, color: isAdmin ? Colors.purple : Colors.blue),
                                        const SizedBox(width: 4),
                                        Text(user['role'].toString().toUpperCase(), style: TextStyle(color: isAdmin ? Colors.purple : Colors.blue, fontWeight: FontWeight.bold, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.grey), onPressed: () {}),
                                  IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => _showDeleteDialog(user['id'])),
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
