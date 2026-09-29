import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/login_screen.dart';

void main() {
  runApp(const HelpdeskApp());
}

class HelpdeskApp extends StatelessWidget {
  const HelpdeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helpdesk App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(
          0xFFF8FAFC,
        ), // Background abu-abu terang
        primaryColor: const Color(0xFF48CEA4), // Mint Green
        textTheme:
            GoogleFonts.interTextTheme(), // Font profesional ala korporat
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF48CEA4),
          primary: const Color(0xFF48CEA4),
          secondary: const Color(0xFF1E293B), // Navy Slate
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
