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

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.red,
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_bus, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                const Text(
                  'TravelNepal+',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Map Tracking'),
            selected: selectedIndex == 0,
            selectedColor: Colors.red,
            onTap: () {
              Navigator.pop(context); // Close drawer
              onItemSelected(0);
            },
          ),
          ListTile(
            leading: const Icon(Icons.directions_bus),
            title: const Text('Routes'),
            selected: selectedIndex == 1,
            selectedColor: Colors.red,
            onTap: () {
              Navigator.pop(context); // Close drawer
              onItemSelected(1);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            selected: selectedIndex == 2,
            selectedColor: Colors.red,
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
