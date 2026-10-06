import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'new_password_screen.dart';
import 'otp_verification_screen.dart';
import 'two_factor_auth_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _selectedIndex = 0;

  // Controller baru untuk menangkap input email
  final TextEditingController _emailController = TextEditingController();

  static const Color primaryMintGreen = Color(0xFF48CEA4);
  static const Color primaryText = Color(0xFF1E293B);
  static const Color subtext = Color(0xFF94A3B8);
  static const Color cardInactiveBg = Color(0xFFF1F5F9);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendOtpViaEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address first!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sending OTP...')),
    );

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8080/api/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(email: email),
          ),
        );
      } else {
        final body = jsonDecode(response.body);
        final message = body['message'] ?? 'Failed to send OTP';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cardInactiveBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: primaryText,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Header Typography
              const Text(
                'Forgot Password',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Enter your registered email and select a method to receive your reset code 🔑',
                style: TextStyle(fontSize: 16, color: subtext, height: 1.5),
              ),
              const SizedBox(height: 32),

              // Kolom Input Email Baru
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Enter your email address',
                  hintStyle: const TextStyle(color: subtext),
                  prefixIcon: const Icon(Icons.email_outlined, color: subtext),
                  filled: true,
                  fillColor: cardInactiveBg,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: primaryMintGreen,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Select Reset Method',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 16),

              // Selection Cards
              _SelectionCard(
                title: 'Email Address',
                subtitle: 'Send OTP via Email',
                icon: Icons.email_outlined,
                isSelected: _selectedIndex == 0,
                onTap: () {
                  setState(() {
                    _selectedIndex = 0;
                  });
                },
              ),
              const SizedBox(height: 16),
              _SelectionCard(
                title: '2FA Authentication',
                subtitle: 'Send OTP via Authenticator',
                icon: Icons.lock_outline,
                isSelected: _selectedIndex == 1,
                onTap: () {
                  setState(() {
                    _selectedIndex = 1;
                  });
                },
              ),
              const SizedBox(height: 16),
              _SelectionCard(
                title: 'Google Auth',
                subtitle: 'Reset via Google Account',
                icon: Icons.shield_outlined,
                isSelected: _selectedIndex == 2,
                onTap: () {
                  setState(() {
                    _selectedIndex = 2;
                  });
                },
              ),
              const SizedBox(height: 48),

              // Bottom Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    switch (_selectedIndex) {
                      case 0:
                        _sendOtpViaEmail();
                        break;
                      case 1:
                        // 2FA: Langsung ke layar 2FA
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const TwoFactorAuthScreen(),
                          ),
                        );
                        break;
                      case 2:
                        // Google Auth: Tampilkan loading, lalu ke New Password
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext dialogContext) {
                            return const AlertDialog(
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: primaryMintGreen,
                                  ),
                                  SizedBox(height: 16),
                                  Text('Connecting to Google...'),
                                ],
                              ),
                            );
                          },
                        );
                        Future.delayed(
                          const Duration(seconds: 2),
                          () {
                            if (!context.mounted) return;
                            Navigator.pop(context); // Tutup dialog
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    NewPasswordScreen(email: _emailController.text.trim()),
                              ),
                            );
                          },
                        );
                        break;
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryMintGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Submit Reset',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.check, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color primaryMintGreen = Color(0xFF48CEA4);
    const Color primaryText = Color(0xFF1E293B);
    const Color subtext = Color(0xFF94A3B8);
    const Color cardInactiveBg = Color(0xFFF1F5F9);
    const Color darkGrey = Color(0xFF334155);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : cardInactiveBg,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: primaryMintGreen, width: 1.5)
              : Border.all(color: Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            // Leading
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: darkGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            // Center
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: subtext,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Trailing
            Icon(
              Icons.chevron_right,
              color: isSelected ? primaryMintGreen : subtext,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
