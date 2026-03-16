import 'package:flutter/material.dart';
import 'package:frontend/api_service.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/screens/map_tracking_screen.dart';
import 'package:frontend/screens/route_listing_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/widgets/app_drawer.dart';

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
      return const Center(child: CircularProgressIndicator()); 
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: Colors.red,
            child: Icon(Icons.person, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 16),
           Text(
            _currentUser!.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _currentUser!.email,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _currentUser!.role == 'admin' ? Colors.red : Colors.grey[300],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _currentUser!.role.toUpperCase(),
              style: TextStyle(
                color: _currentUser!.role == 'admin' ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_currentUser!.role == 'admin') ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Admin Dashboard'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Admin dashboard coming soon!')),
                );
              },
            ),
            const Divider(),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
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
              child: const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = 'TravelNepal+';
    if (_selectedIndex == 0) title = 'Map Tracking';
    if (_selectedIndex == 1) title = 'All Routes';
    if (_selectedIndex == 2) title = 'My Profile';

    final List<Widget> widgetOptions = <Widget>[
      const MapTrackingScreen(showAppBar: false), // I will add this parameter
      const RouteListingScreen(showAppBar: false), // I will add this parameter
      _buildProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      drawer: AppDrawer(
        selectedIndex: _selectedIndex,
        onItemSelected: _onItemTapped,
      ),
      body: widgetOptions.elementAt(_selectedIndex),
    );
  }
}
