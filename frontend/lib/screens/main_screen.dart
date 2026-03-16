import 'package:flutter/material.dart';
import 'package:frontend/api_service.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/screens/map_tracking_screen.dart';
import 'package:frontend/screens/route_listing_screen.dart';
import 'package:frontend/screens/login_screen.dart';

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
      // Navigate to Login Screen if not logged in and tapping Profile
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      ).then((_) {
        // Re-check login status when coming back
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
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
                  setState(() {
                    _currentUser = null;
                    _selectedIndex = 0; // Go back to map
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = <Widget>[
      const MapTrackingScreen(),
      const RouteListingScreen(),
      _buildProfileTab(),
    ];

    return Scaffold(
      body: widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus),
            label: 'Routes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.red,
        onTap: _onItemTapped,
      ),
    );
  }
}
