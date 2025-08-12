import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  void _togglePassword() =>
      setState(() => _obscurePassword = !_obscurePassword);

  String? _validateNotEmpty(String? val, String field) {
    if (val == null || val.trim().isEmpty) return '$field is required';
    if (field == 'Email' && !RegExp(r'^\S+@\S+\.\S+$').hasMatch(val.trim()))
      return 'Invalid email';
    return null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, dynamic> parseJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) throw Exception('Invalid JWT token format');

    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final payloadMap = json.decode(decoded);

    if (payloadMap is! Map<String, dynamic>)
      throw Exception('Invalid JWT payload structure');
    return payloadMap;
  }

  Future<void> _saveUserData(
      Map<String, dynamic> userData, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('user', jsonEncode(userData));
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        role: 'admin',
      );

      final token = result['token'] ?? '';
      if (token.isEmpty) throw Exception('Login failed: no token returned');

      String userId = result['userId'] ?? '';
      String userName = result['name'] ?? '';
      String role = result['role'] ?? '';
      String email = result['email'] ?? '';

      if ([userId, userName, role, email].any((val) => val.isEmpty)) {
        final payload = parseJwt(token);

        userId = userId.isNotEmpty
            ? userId
            : (payload['userId'] ?? payload['id'] ?? '');
        userName = userName.isNotEmpty
            ? userName
            : (payload['name'] ?? payload['username'] ?? '');
        role = role.isNotEmpty ? role : (payload['role'] ?? '');
        email = email.isNotEmpty ? email : (payload['email'] ?? '');

        final userDataFromToken = {
          'userId': userId,
          'name': userName,
          'role': role,
          'email': email,
        };

        print('Decoded userData from token: $userDataFromToken');

        await _saveUserData(userDataFromToken, token);

        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomePage()));
        return;
      }

      final userData = {
        'userId': userId,
        'name': userName,
        'role': role,
        'email': email,
      };

      print('User data from API response: $userData');

      await _saveUserData(userData, token);

      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomePage()));
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Welcome Back',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Sign in to continue',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: Colors.grey[600])),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => _validateNotEmpty(v, 'Email'),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: _togglePassword,
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (v) => _validateNotEmpty(v, 'Password'),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Login', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
