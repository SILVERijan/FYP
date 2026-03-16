import 'package:flutter/material.dart';
import 'package:frontend/api_service.dart';
import 'package:frontend/screens/login_screen.dart';

class AppDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final ApiService apiService = ApiService();
    final theme = Theme.of(context);

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.colorScheme.primary, Colors.red[800]!],
              ),
            ),
            accountName: const Text(
              'Samaya Sawari',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            accountEmail: const Text('Public Transport Tracking'),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.directions_bus, color: Colors.red, size: 30),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Map Tracking'),
            selected: selectedIndex == 0,
            selectedColor: theme.colorScheme.primary,
            iconColor: Colors.black87,
            textColor: Colors.black87,
            onTap: () {
              Navigator.pop(context); // Close drawer
              onItemSelected(0);
            },
          ),
          ListTile(
            leading: const Icon(Icons.directions_bus),
            title: const Text('Routes'),
            selected: selectedIndex == 1,
            selectedColor: theme.colorScheme.primary,
            iconColor: Colors.black87,
            textColor: Colors.black87,
            onTap: () {
              Navigator.pop(context); // Close drawer
              onItemSelected(1);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            selected: selectedIndex == 2,
            selectedColor: theme.colorScheme.primary,
            iconColor: Colors.black87,
            textColor: Colors.black87,
            onTap: () {
              Navigator.pop(context); // Close drawer
              onItemSelected(2);
            },
          ),
          const Divider(),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await apiService.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
