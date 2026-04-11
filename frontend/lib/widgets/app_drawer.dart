import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend/api_service.dart';
import 'package:frontend/models/user.dart';
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: FutureBuilder<User?>(
        future: apiService.getCurrentUser(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clean Minimalist Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 2),
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.grey[100],
                        backgroundImage: user?.profile_picture != null
                            ? NetworkImage(apiService.getProfileImageUrl(user!.profile_picture))
                            : null,
                        child: user?.profile_picture == null
                            ? const Icon(Icons.person_rounded, color: Colors.black45, size: 32)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      user?.name ?? 'Samaya Sawari',
                      style: theme.textTheme.headlineMedium?.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'Public Transit Tracking',
                      style: const TextStyle(color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideX(begin: -0.1),
              
              const SizedBox(height: 8),
              
              _DrawerItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map_rounded,
                label: 'Map Tracking',
                isSelected: selectedIndex == 0,
                onTap: () {
                  Navigator.pop(context);
                  onItemSelected(0);
                },
              ),
              _DrawerItem(
                icon: Icons.directions_bus_outlined,
                activeIcon: Icons.directions_bus_rounded,
                label: 'Routes & Schedules',
                isSelected: selectedIndex == 1,
                onTap: () {
                  Navigator.pop(context);
                  onItemSelected(1);
                },
              ),
              _DrawerItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile Settings',
                isSelected: selectedIndex == 2,
                onTap: () {
                  Navigator.pop(context);
                  onItemSelected(2);
                },
              ),
              
              if (user?.role == 'admin') ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 32, 24, 12),
                  child: Text(
                    'ADMINISTRATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.black26,
                      letterSpacing: 1.5,
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms),
                _DrawerItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  label: 'Analytics Dashboard',
                  isSelected: selectedIndex == 3,
                  onTap: () {
                    Navigator.pop(context);
                    onItemSelected(3);
                  },
                ),
                _DrawerItem(
                  icon: Icons.people_outline_rounded,
                  activeIcon: Icons.people_rounded,
                  label: 'User Management',
                  isSelected: selectedIndex == 4,
                  onTap: () {
                    Navigator.pop(context);
                    onItemSelected(4);
                  },
                ),
                _DrawerItem(
                  icon: Icons.directions_car_outlined,
                  activeIcon: Icons.directions_car_rounded,
                  label: 'Transport Fleet',
                  isSelected: selectedIndex == 5,
                  onTap: () {
                    Navigator.pop(context);
                    onItemSelected(5);
                  },
                ),
                _DrawerItem(
                  icon: Icons.alt_route_outlined,
                  activeIcon: Icons.alt_route_rounded,
                  label: 'Route Manager',
                  isSelected: selectedIndex == 6,
                  onTap: () {
                    Navigator.pop(context);
                    onItemSelected(6);
                  },
                ),
              ],
              
              const Spacer(),
              
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: TextButton.icon(
                  onPressed: () async {
                    await apiService.logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, color: Colors.black87, size: 20),
                  label: const Text('Sign out', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isSelected ? Colors.black : Colors.transparent,
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? Colors.white : Colors.black87,
          size: 24,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.05);
  }
}
