import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'login_screen.dart';

class NewPasswordScreen extends StatefulWidget {
  final String email;

  const NewPasswordScreen({super.key, required this.email});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color mintGreen = Color(0xFF48CEA4);
  static const Color navySlate = Color(0xFF1E293B);
  static const Color greyText = Color(0xFF94A3B8);
  static const Color errorRed = Color(0xFFFF5252);

  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isMismatch = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_checkPasswordMatch);
    _confirmPasswordController.addListener(_checkPasswordMatch);
  }

  void _checkPasswordMatch() {
    final pass = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (confirm.isNotEmpty && pass != confirm) {
      if (!_isMismatch) setState(() => _isMismatch = true);
    } else {
      if (_isMismatch) setState(() => _isMismatch = false);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSuccessModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: mintGreen, size: 80),
              const SizedBox(height: 24),
              const Text(
                'Password Reset Successful',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: navySlate,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You can now log in with your new password.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: greyText),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mintGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Back to Login',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Bar: Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back, color: navySlate),
              ),
              const SizedBox(height: 32),

              // 2. Header
              const Text(
                'Create New Password',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: navySlate,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your new password must be different from previous used passwords.',
                style: TextStyle(fontSize: 14, color: greyText),
              ),
              const SizedBox(height: 40),

              // 3. Inputs
              _buildPasswordField(
                hint: 'New Password',
                controller: _passwordController,
                isObscured: _obscurePassword,
                onToggleVisibility: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildConfirmPasswordField(),

              const SizedBox(height: 40),

              // 4. Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_passwordController.text.isEmpty ||
                        _confirmPasswordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Semua kolom harus diisi!'),
                        ),
                      );
                      return;
                    }
                    if (_isMismatch) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tolong perbaiki password Anda'),
                        ),
                      );
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Updating password...')),
                    );

                    try {
                      final response = await http.post(
                        Uri.parse('http://10.0.2.2:8080/api/auth/reset-password'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({
                          'email': widget.email,
                          'newPassword': _passwordController.text,
                        }),
                      );

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();

                      if (response.statusCode == 200) {
                        _showSuccessModal();
                      } else {
                        final body = jsonDecode(response.body);
                        final message = body['message'] ?? 'Failed to reset password';
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
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mintGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required String hint,
    required TextEditingController controller,
    required bool isObscured,
    required VoidCallback onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: isObscured,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: greyText),
        prefixIcon: const Icon(Icons.lock_outline, color: greyText),
        suffixIcon: IconButton(
          icon: Icon(
            isObscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: greyText,
          ),
          onPressed: onToggleVisibility,
        ),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: mintGreen),
        ),
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          style: TextStyle(color: _isMismatch ? errorRed : navySlate),
          decoration: InputDecoration(
            hintText: 'Confirm New Password',
            hintStyle: TextStyle(
              color: _isMismatch ? errorRed.withValues(alpha: 0.6) : greyText,
            ),
            prefixIcon: Icon(
              Icons.lock_outline,
              color: _isMismatch ? errorRed : greyText,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: _isMismatch ? errorRed : greyText,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
            filled: true,
            fillColor: _isMismatch
                ? errorRed.withValues(alpha: 0.05)
                : Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _isMismatch
                    ? errorRed
                    : Colors.grey.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _isMismatch ? errorRed : mintGreen),
            ),
          ),
        ),
        if (_isMismatch)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 4.0),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: errorRed,
                  size: 16,
                ),
                const SizedBox(width: 4),
                const Text(
                  'ERROR: Passwords do not match!',
                  style: TextStyle(color: errorRed, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
