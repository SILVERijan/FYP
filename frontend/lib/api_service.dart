import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models/user.dart';
import 'models/transport_route.dart';
import 'models/vehicle.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> logout() async {
    final token = await getToken();
    if (token != null) {
      await http.post(
        Uri.parse('$baseUrl/logout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
  }

  Future<bool> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveToken(data['access_token']);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(data['user']));
      return true;
    }
    return false;
  }

  Future<bool> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await saveToken(data['access_token']);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(data['user']));
      return true;
    }
    return false;
  }

  Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    if (userData != null) {
      return User.fromJson(jsonDecode(userData));
    }
    return null;
  }

  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'Error', 'message': 'Server returned ${response.statusCode}'};
      }
    } catch (e) {
      return {'status': 'Error', 'message': 'Could not connect to backend: $e'};
    }
  }

  Future<List<TransportRoute>> getRoutes() async {
    final response = await http.get(Uri.parse('$baseUrl/transport/routes'));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => TransportRoute.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load routes');
    }
  }

  Future<TransportRoute> getRouteDetails(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/transport/routes/$id'));
    if (response.statusCode == 200) {
      return TransportRoute.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load route details');
    }
  }

  Future<List<Vehicle>> getVehicles() async {
    final response = await http.get(Uri.parse('$baseUrl/transport/vehicles'));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => Vehicle.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load vehicles');
    }
  }
}
