import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api_config.dart';

class AuthService {
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String role,
  }) async {
    final baseUrl = getBackendBaseUrl();
    final url = Uri.parse('$baseUrl/api/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "email": email,
          "password": password,
          "role": role,
        }),
      );

      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', data['token']);
          await prefs.setString(
              'user',
              jsonEncode({
                'userId': data['userId'],
                'name': data['name'],
                'role': data['role'],
                'email': data['email'],
              }));
        }

        return data;
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Login failed');
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }
}
