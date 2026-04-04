import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/user.dart';
import 'models/transport_route.dart';
import 'models/vehicle.dart';

class ApiService {
  static String get baseUrl => Platform.isAndroid ? 'http://10.0.2.2:8080/api' : 'http://127.0.0.1:8080/api';
  static String get serverUrl => Platform.isAndroid ? 'http://10.0.2.2:8080' : 'http://127.0.0.1:8080';

  // ... (existing methods kept for brevety, but I will replace the whole file content to be safe and clean)

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

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await saveToken(data['access_token']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(data['user']));
        return {'success': true, 'message': 'Login successful'};
      }
      
      String message = 'Login failed';
      if (data['message'] != null) message = data['message'];
      if (data['errors'] != null) {
        final errors = data['errors'] as Map<String, dynamic>;
        message = errors.values.first[0];
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        await saveToken(data['access_token']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(data['user']));
        return {'success': true, 'message': 'Registration successful'};
      }

      String message = 'Registration failed';
      if (data['message'] != null) message = data['message'];
      if (data['errors'] != null) {
        final errors = data['errors'] as Map<String, dynamic>;
        message = errors.values.first[0];
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
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

  Future<Map<String, dynamic>> updateProfile(String name, File? image) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/user/update'));
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.fields['name'] = name;

      if (image != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'profile_picture',
          image.path,
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(data['user']));
        return {
          'success': true, 
          'message': 'Profile updated successfully', 
          'user': User.fromJson(data['user'])
        };
      }

      return {'success': false, 'message': data['message'] ?? 'Update failed'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  String getProfileImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$serverUrl/storage/$path';
  }
}
