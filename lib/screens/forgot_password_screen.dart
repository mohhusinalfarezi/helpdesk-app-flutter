import 'package:flutter/material.dart';

import 'otp_verification_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _selectedIndex = 0;

  static const Color primaryMintGreen = Color(0xFF48CEA4);
  static const Color primaryText = Color(0xFF1E293B);
  static const Color subtext = Color(0xFF94A3B8);
  static const Color cardInactiveBg = Color(0xFFF1F5F9);

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
                'Forgot your password? Then let\'s submit password reset 🔑',
                style: TextStyle(fontSize: 16, color: subtext, height: 1.5),
              ),
              const SizedBox(height: 32),

              // Selection Cards
              _SelectionCard(
                title: 'Email Address',
                subtitle: 'Seamlessly reset your password via Email Address',
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
                subtitle: 'Seamlessly reset your password via 2 Factor Auth',
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
                subtitle: 'Seamlessly reset your password via Google Auth',
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
                    // Navigasi ke layar OTP
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OtpVerificationScreen(),
                      ),
                    );
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
