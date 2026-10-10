import 'dashboard_screen.dart';
import 'technician_dashboard_screen.dart';

import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _extractRoleFromJwt(String? token) {
    if (token == null || token.isEmpty) return 'USER';
    try {
      final parts = token.split('.');
      if (parts.length >= 2) {
        final payloadPart = parts[1];
        final normalized = base64Url.normalize(payloadPart);
        final decodedBytes = base64Url.decode(normalized);
        final decodedString = utf8.decode(decodedBytes);
        final Map<String, dynamic> payloadMap = jsonDecode(decodedString);

        dynamic rawRole = payloadMap['role'] ??
            payloadMap['roles'] ??
            payloadMap['authorities'] ??
            payloadMap['roleName'];

        if (rawRole is List && rawRole.isNotEmpty) {
          rawRole = rawRole.first;
        }

        if (rawRole != null) {
          String roleStr = rawRole.toString().trim().toUpperCase();
          if (roleStr.startsWith('ROLE_')) {
            roleStr = roleStr.substring(5);
          }
          return roleStr;
        }
      }
    } catch (e) {
      debugPrint('Error decoding role from JWT: $e');
    }
    return 'USER';
  }

  Future<void> _login() async {
    final email = _emailController.text;
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email dan Password tidak boleh kosong')),
      );
      return;
    }

    // CATATAN: Gunakan '10.0.2.2' untuk Emulator Android.
    // Jika menguji lewat Chrome/Web, ganti menjadi 'localhost'.
    final url = Uri.parse('http://10.0.2.2:8080/api/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        debugPrint('ISI RESPONSE BACKEND: ${response.body}');
        final data = jsonDecode(response.body);
        final token = data['token']?.toString() ?? '';
        final name = data['name'] ?? 'Pengguna'; // Extract name

        // Ekstrak role dari JWT token (fallback ke response body jika ada)
        String role = _extractRoleFromJwt(token);
        if (role == 'USER' && data is Map && data['role'] != null) {
          String resRole = data['role'].toString().trim().toUpperCase();
          if (resRole.startsWith('ROLE_')) {
            resRole = resRole.substring(5);
          }
          if (resRole.isNotEmpty) {
            role = resRole;
          }
        }

        // Menyimpan token JWT, nama, dan role ke memori HP
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        await prefs.setString('user_name', name);
        await prefs.setString('user_role', role);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Login Berhasil! Token disimpan.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Color(0xFF48CEA4),
          ),
        );

        // Navigasi berdasarkan role (Role-Based Routing)
        if (role == 'TECHNICIAN' || role == 'ADMIN') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const TechnicianDashboardScreen(),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const DashboardScreen(),
            ),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login gagal. Periksa kembali kredensial Anda.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan jaringan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.support_agent_rounded,
                size: 80,
                color: Color(0xFF48CEA4),
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome Back',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to your helpdesk account',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'email@company.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF48CEA4),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF48CEA4),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // Navigasi ke layar Forgot Password
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF48CEA4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'LOGIN',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account?",
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigasi ke layar Register
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Register',
                      style: TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
