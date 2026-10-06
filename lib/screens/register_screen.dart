import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Palet Warna
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color mintGreen = Color(0xFF48CEA4);
  static const Color navySlate = Color(0xFF1E293B);
  static const Color greyText = Color(0xFF94A3B8);
  static const Color errorRed = Color(0xFFFF5252);

  // Controller untuk membaca inputan teks
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Variabel State
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isMismatch = false;

  @override
  void initState() {
    super.initState();
    // Memantau setiap perubahan teks pada kolom password
    _passwordController.addListener(_checkPasswordMatch);
    _confirmPasswordController.addListener(_checkPasswordMatch);
  }

  void _checkPasswordMatch() {
    final pass = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    // Munculkan error HANYA jika kolom confirm sudah diisi dan isinya tidak sama
    if (confirm.isNotEmpty && pass != confirm) {
      if (!_isMismatch) setState(() => _isMismatch = true);
    } else {
      if (_isMismatch) setState(() => _isMismatch = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
              // 1. Tombol Back
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back, color: navySlate),
              ),
              const SizedBox(height: 32),

              // 2. Header
              const Text(
                'Register Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: navySlate,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Request access to Corporate IT Support.',
                style: TextStyle(fontSize: 14, color: greyText),
              ),
              const SizedBox(height: 40),

              // 3. Form Inputs
              _buildTextField(
                hint: 'Full Name',
                icon: Icons.person_outline,
                controller: _nameController,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                hint: 'Corporate Email',
                icon: Icons.email_outlined,
                controller: _emailController,
              ),
              const SizedBox(height: 16),

              // Kolom Password Pertama
              _buildPasswordField(
                hint: 'Password',
                controller: _passwordController,
                isObscured: _obscurePassword,
                onToggleVisibility: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Kolom Confirm Password (Dinamis)
              _buildConfirmPasswordField(),

              const SizedBox(height: 40),

              // 4. Tombol Register
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // 1. Validasi Input Kosong & Password Match
                    if (_isMismatch) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tolong perbaiki password Anda'),
                        ),
                      );
                      return;
                    }

                    final name = _nameController.text.trim();
                    final email = _emailController.text.trim();
                    final password = _passwordController.text;

                    if (name.isEmpty || email.isEmpty || password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Semua kolom harus diisi!'),
                        ),
                      );
                      return;
                    }

                    // 2. Tampilkan indikator loading (Opsional tapi bagus untuk UX)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sedang mendaftarkan akun...'),
                      ),
                    );

                    // 3. Panggil API Backend Spring Boot
                    final url = Uri.parse(
                      'http://10.0.2.2:8080/api/auth/register',
                    );

                    try {
                      final response = await http.post(
                        url,
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({
                          'name': name,
                          'email': email,
                          'password': password,
                        }),
                      );

                      if (response.statusCode == 200) {
                        // Sukses masuk database
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Registrasi Berhasil! Silakan Sign In.',
                              ),
                              backgroundColor: mintGreen,
                            ),
                          );
                          Navigator.pop(context); // Kembali ke Login
                        }
                      } else {
                        // Gagal (misal: Email sudah terdaftar)
                        final data = jsonDecode(response.body);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                data['message'] ?? 'Registrasi gagal',
                              ),
                              backgroundColor: errorRed,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      // Error jaringan / Server mati
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Error jaringan: Tidak dapat terhubung ke server.',
                            ),
                            backgroundColor: errorRed,
                          ),
                        );
                      }
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
                    'Sign Up ->',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 5. Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(color: greyText),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context), // Kembali ke Login
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        color: mintGreen,
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

  // --- Widget Bantuan ---

  Widget _buildTextField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: greyText),
        prefixIcon: Icon(icon, color: greyText),
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
            hintText: 'Confirm Password',
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
        // Pesan Error akan muncul HANYA jika _isMismatch bernilai true
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
