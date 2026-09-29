import 'package:flutter/material.dart';

class TicketTrackerScreen extends StatelessWidget {
  const TicketTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Track Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF48CEA4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Ticket Tracker is coming soon!',
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }
}
