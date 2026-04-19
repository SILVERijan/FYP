import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend/api_service.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/screens/map_tracking_screen.dart';
import 'package:frontend/screens/route_listing_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/edit_profile_screen.dart';
import 'package:frontend/widgets/app_drawer.dart';
import 'package:frontend/widgets/desktop_sidebar.dart';
import 'package:frontend/screens/desktop_routes_dashboard.dart';
import 'package:frontend/screens/admin_dashboard_screen.dart';
import 'package:frontend/screens/admin/user_management_screen.dart';
import 'package:frontend/screens/admin/vehicle_management_screen.dart';
import 'package:frontend/screens/admin/route_management_screen.dart';
import 'package:frontend/screens/driver_dashboard_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final ApiService _apiService = ApiService();
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final user = await _apiService.getCurrentUser();
    setState(() {
      _currentUser = user;
    });
  }

  void _onItemTapped(int index) {
    if (index == 2 && _currentUser == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      ).then((_) {
        _checkLoginStatus();
      });
      return;
    }
    
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildProfileTab() {
    if (_currentUser == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.black)); 
    }

    final theme = Theme.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentUser!.name,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentUser!.email,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  if (_currentUser?.company_name != null && _currentUser!.company_name!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        _currentUser!.company_name!,
                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12, width: 2),
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _currentUser?.profile_picture != null
                      ? NetworkImage(_apiService.getProfileImageUrl(_currentUser!.profile_picture))
                      : null,
                  child: _currentUser?.profile_picture == null
                      ? const Icon(Icons.person, size: 40, color: Colors.black)
                      : null,
                ),
              ),
            ],
          ).animate().fadeIn().slideY(begin: 0.1),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _currentUser!.role.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 1.0,
              ),
            ),
          ).animate().fadeIn(delay: 200.ms),
          
          const SizedBox(height: 48),
          
          const Text(
            'Account Info',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black26, letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),
          _buildProfileItem(Icons.edit_outlined, 'Edit Profile', onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => EditProfileScreen(user: _currentUser!)),
            ).then((value) {
              if (value == true) _checkLoginStatus();
            });
          }),
          if (_currentUser!.role == 'driver')
            _buildProfileItem(Icons.sensors_rounded, 'Driver Dashboard', onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DriverDashboardScreen(user: _currentUser!)),
              );
            }),
          _buildProfileItem(Icons.security_outlined, 'Security'),
          _buildProfileItem(Icons.notifications_none_rounded, 'Notifications'),
          
          const SizedBox(height: 32),
          
          const SizedBox(height: 16),
          
          const SizedBox(height: 40),
          
          TextButton.icon(
            onPressed: () async {
              await _apiService.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.black87),
            label: const Text('Log out', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
            ),
          ),
          
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F1F1))),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: Colors.black, size: 24),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black, fontSize: 16),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
        onTap: onTap ?? () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.black)));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 800;

        // 1. DYNAMICALLY ASSEMBLE TABS
        final List<Map<String, dynamic>> primaryTabs = [
          {'label': 'Map', 'icon': Icons.map_outlined, 'activeIcon': Icons.map_rounded, 'screen': const MapTrackingScreen(showAppBar: false)},
          {'label': 'Routes', 'icon': Icons.directions_bus_outlined, 'activeIcon': Icons.directions_bus_rounded, 'screen': const RouteListingScreen(showAppBar: false)},
        ];

        // Insert Driver Dashboard if user is Driver or Admin
        if (_currentUser!.role == 'driver' || _currentUser!.role == 'admin') {
          primaryTabs.add({
            'label': 'Driver', 
            'icon': Icons.sensors_outlined, 
            'activeIcon': Icons.sensors_rounded, 
            'screen': DriverDashboardScreen(user: _currentUser!)
          });
        }

        primaryTabs.add({'label': 'Profile', 'icon': Icons.person_outline_rounded, 'activeIcon': Icons.person_rounded, 'screen': SafeArea(child: _buildProfileTab())});

        // 2. BUILD BOTTOM NAV ITEMS
        List<BottomNavigationBarItem> bottomNavItems = primaryTabs.map((tab) => BottomNavigationBarItem(
          icon: Icon(tab['icon'], size: 24), 
          activeIcon: Icon(tab['activeIcon'], size: 24), 
          label: tab['label']
        )).toList();

        if (_currentUser?.role == 'admin') {
          bottomNavItems.add(const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_outlined, size: 24), activeIcon: Icon(Icons.admin_panel_settings_rounded, size: 24), label: 'Admin'));
        }

        // 3. ASSEMBLE SCREEN STACK
        final List<Widget> screens = primaryTabs.map<Widget>((tab) => tab['screen'] as Widget).toList();
        if (_currentUser?.role == 'admin') {
          screens.addAll([
            const AdminDashboardScreen(),
            const UserManagementScreen(),
            const VehicleManagementScreen(),
            const RouteManagementScreen(),
          ]);
        }

        int safeIndex = _selectedIndex < screens.length ? _selectedIndex : 0;

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                DesktopSidebar(
                  selectedIndex: _selectedIndex,
                  onItemSelected: _onItemTapped,
                ),
                Expanded(
                  child: IndexedStack(
                    index: safeIndex,
                    children: screens,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          drawer: AppDrawer(
            selectedIndex: _selectedIndex,
            onItemSelected: _onItemTapped,
          ),
          body: Stack(
            children: [
              IndexedStack(
                index: safeIndex,
                children: screens,
              ),
              // Floating "Where to?" Search Bar for Map tab
              if (safeIndex == 0)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () {
                      // Trigger search or route selection
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, color: Colors.black),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Where to?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            height: 24,
                            width: 1,
                            color: Colors.black12,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          const Icon(Icons.schedule_rounded, color: Colors.black),
                          const SizedBox(width: 8),
                          const Text(
                            'Now',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
                ),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05))),
            ),
            child: BottomNavigationBar(
              currentIndex: safeIndex,
              type: BottomNavigationBarType.fixed,
              onTap: _onItemTapped,
              selectedItemColor: Colors.black,
              unselectedItemColor: Colors.black26,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.2),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
              elevation: 0,
              backgroundColor: Colors.transparent,
              items: bottomNavItems,
            ),
          ),
        );
      },
    );
  }
}
