import 'package:flutter/material.dart';

class TicketTrackerScreen extends StatefulWidget {
  const TicketTrackerScreen({super.key});

  @override
  State<TicketTrackerScreen> createState() => _TicketTrackerScreenState();
}

class _TicketTrackerScreenState extends State<TicketTrackerScreen> {
  // Color Palette
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color mintGreen = Color(0xFF48CEA4);
  static const Color navySlate = Color(0xFF1E293B);
  static const Color greyText = Color(0xFF94A3B8); // Slate 400
  static const Color darkGreen = Color(0xFF1A5340); // Darker shade of mint
  static const Color cardShadowColor = Color(0x0A000000); // Very subtle shadow

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: mintGreen,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_comment_outlined, color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildPriorityCard(),
              const SizedBox(height: 24),
              _buildStatsRow(),
              const SizedBox(height: 32),
              _buildListHeader(),
              const SizedBox(height: 16),
              _buildTicketList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Corporate IT Support",
              style: TextStyle(
                color: greyText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              "Hello, Moh. Husin",
              style: TextStyle(
                color: navySlate,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
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
              child: Text(
                "MH",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriorityCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: mintGreen,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: mintGreen.withValues(alpha: 0.3),
            blurRadius: 16,
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
                children: const [
                  Icon(Icons.shield_outlined, color: darkGreen, size: 18),
                  SizedBox(width: 8),
                  Text(
                    "HELPDESK PRIORITY",
                    style: TextStyle(
                      color: darkGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const Text(
                "Updated just now",
                style: TextStyle(
                  color: darkGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            "1 Active Ticket",
            style: TextStyle(
              color: navySlate,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Assigned to Level 2 technical engineering queue.",
            style: TextStyle(
              color: darkGreen,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: const [
              Icon(Icons.bolt, color: darkGreen, size: 18),
              SizedBox(width: 8),
              Text(
                "Next SLA breach in 4 hours 12 mins",
                style: TextStyle(
                  color: darkGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatCard("AVG RESPONSE", "14 Mins")),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard("RESOLUTION RATE", "98.4%")),
      ],
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: cardShadowColor,
            blurRadius: 10,
            offset: Offset(0, 4),
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: navySlate,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          "Recent Tickets",
          style: TextStyle(
            color: navySlate,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            "View All >",
            style: TextStyle(
              color: mintGreen,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketList() {
    return Column(
      children: [
        _buildTicketCard(
          ticketId: "TKT-1789",
          status: "OPEN",
          statusColor: const Color(0xFFFEE2E2), // light red
          statusTextColor: const Color(0xFFDC2626), // red
          title: "Login Issue",
          category: "Identity & Access",
          timeText: "Created 2h ago",
        ),
        const SizedBox(height: 16),
        _buildTicketCard(
          ticketId: "TKT-1790",
          status: "IN PROGRESS",
          statusColor: const Color(0xFFDBEAFE), // light blue
          statusTextColor: const Color(0xFF2563EB), // blue
          title: "VPN Access Request",
          category: "Network & Remote",
          timeText: "Updated 45m ago",
        ),
      ],
    );
  }

  Widget _buildTicketCard({
    required String ticketId,
    required String status,
    required Color statusColor,
    required Color statusTextColor,
    required String title,
    required String category,
    required String timeText,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: cardShadowColor,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.confirmation_number_outlined,
                      color: navySlate,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    ticketId,
                    style: const TextStyle(
                      color: navySlate,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
                  color: statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_outlined, color: greyText, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    category,
                    style: const TextStyle(
                      color: greyText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.access_time, color: greyText, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    timeText,
                    style: const TextStyle(
                      color: greyText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
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
