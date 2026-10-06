import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'new_password_screen.dart';

class TwoFactorAuthScreen extends StatelessWidget {
  const TwoFactorAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFF8FAFC);
    const Color mintGreen = Color(0xFF48CEA4);
    const Color navySlate = Color(0xFF1E293B);
    const Color greyColor = Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Bar: Back button
                IconButton(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  icon: const Icon(Icons.arrow_back, color: navySlate),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 32),

                // 2. Header
                const Text(
                  '2FA Verification',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: navySlate,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Enter the 6-digit code from your Authenticator app (e.g., Google Authenticator or Authy).',
                  style: TextStyle(fontSize: 16, color: greyColor),
                ),
                const SizedBox(height: 48),

                // 3. 6-Digit Code Input Area
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 48,
                      height: 48,
                      child: TextField(
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          counterText: "",
                          contentPadding: EdgeInsets.zero,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: mintGreen,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 5) {
                            FocusScope.of(context).nextFocus();
                          } else if (value.isEmpty && index > 0) {
                            FocusScope.of(context).previousFocus();
                          }
                        },
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 48),

                // 4. Verify Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mintGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      // Navigasi ke layar New Password
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NewPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Verify Code',
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
      ),
    );
  }
}
