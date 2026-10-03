import 'package:flutter/material.dart';

import 'chat_screen.dart'; // Import layar chat AI Hazel

class TicketTrackerScreen extends StatelessWidget {
  const TicketTrackerScreen({super.key});

  // Palet Warna
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color mintGreen = Color(0xFF48CEA4);
  static const Color navySlate = Color(0xFF1E293B);
  static const Color greyText = Color(0xFF94A3B8);

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
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildPriorityCard(),
              const SizedBox(height: 16),
              _buildStatsRow(),
              const SizedBox(height: 32),
              _buildRecentTicketsHeader(),
              const SizedBox(height: 16),
              _buildTicketList(),
              const SizedBox(height: 80), // Ruang ekstra untuk FAB
            ],
          ),
        ),
      ),
      // --- PENYESUAIAN TOMBOL MELAYANG (FAB) DI SINI ---
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigasi kembali ke Hazel untuk membuat tiket baru
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
        },
        backgroundColor: mintGreen,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
    );
  }

  // --- 1. Bagian Header ---
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            // Tombol Kembali
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: navySlate,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Corporate IT Support',
                  style: TextStyle(color: greyText, fontSize: 12),
                ),
                SizedBox(height: 4),
                Text(
                  'Hello, Moh. Husin',
                  style: TextStyle(
                    color: navySlate,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: const Icon(
                Icons.notifications_none,
                color: navySlate,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const CircleAvatar(
              radius: 18,
              backgroundColor: mintGreen,
              child: Icon(Icons.person, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  // --- 2. Kartu Prioritas ---
  Widget _buildPriorityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: mintGreen,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: mintGreen.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: navySlate, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'HELPDESK PRIORITY',
                    style: TextStyle(
                      color: navySlate.withValues(alpha: 0.8),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Text(
                'Updated just now',
                style: TextStyle(
                  color: navySlate.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '1 Active Ticket',
            style: TextStyle(
              color: navySlate,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Assigned to Level 2 technical engineering\nqueue.',
            style: TextStyle(
              color: navySlate.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.bolt, color: navySlate, size: 18),
              const SizedBox(width: 8),
              Text(
                'Next SLA breach in 4 hours 12 mins',
                style: TextStyle(
                  color: navySlate.withValues(alpha: 0.9),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 3. Kartu Statistik ---
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('AVG RESPONSE', '14 Mins')),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('RESOLUTION RATE', '98.4%')),
      ],
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: greyText,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: navySlate,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. Header Daftar Tiket ---
  Widget _buildRecentTicketsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Recent Tickets',
          style: TextStyle(
            color: navySlate,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'View All >',
          style: TextStyle(
            color: mintGreen.withValues(alpha: 0.9),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // --- 5. Daftar Tiket ---
  Widget _buildTicketList() {
    return Column(
      children: [
        _buildTicketItem(
          id: 'TKT-1789',
          status: 'OPEN',
          title: 'Login Issue',
          category: 'Identity & Access',
          time: 'Created 2h ago',
          statusColor: const Color(0xFFFF5252),
          statusBgColor: const Color(0xFFFF5252).withValues(alpha: 0.1),
        ),
        const SizedBox(height: 16),
        _buildTicketItem(
          id: 'TKT-1790',
          status: 'IN PROGRESS',
          title: 'Electric Connectivity Issue',
          category: 'Network & Remote',
          time: 'Updated 45m ago',
          statusColor: const Color(0xFF448AFF),
          statusBgColor: const Color(0xFF448AFF).withValues(alpha: 0.1),
        ),
      ],
    );
  }

  Widget _buildTicketItem({
    required String id,
    required String status,
    required String title,
    required String category,
    required String time,
    required Color statusColor,
    required Color statusBgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.confirmation_num_outlined,
                    color: mintGreen,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    id,
                    style: const TextStyle(
                      color: greyText,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: navySlate,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_open, color: greyText, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    category,
                    style: const TextStyle(color: greyText, fontSize: 12),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.access_time, color: greyText, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    time,
                    style: const TextStyle(color: greyText, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
