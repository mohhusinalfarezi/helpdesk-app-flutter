import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_screen.dart';

class TicketTrackerScreen extends StatefulWidget {
  const TicketTrackerScreen({super.key});

  @override
  State<TicketTrackerScreen> createState() => _TicketTrackerScreenState();
}

class _TicketTrackerScreenState extends State<TicketTrackerScreen> {
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color mintGreen = Color(0xFF48CEA4);
  static const Color navySlate = Color(0xFF1E293B);
  static const Color greyText = Color(0xFF94A3B8);

  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _tickets = [];
  String _userName = "Pengguna";

  // Variabel untuk data dinamis kartu hijau dan statistik
  int _activeTicketsCount = 0;
  int _resolvedTicketsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _fetchTicketsData();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? "Pengguna";
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return "Selamat pagi,";
    if (hour < 15) return "Selamat siang,";
    if (hour < 18) return "Selamat sore,";
    return "Selamat malam,";
  }

  Future<void> _fetchTicketsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. Ambil token dari memori perangkat
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      debugPrint('=== ISI TOKEN DARI MEMORI: $token ===');

      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = 'Sesi login tidak valid. Silakan login ulang.';
          _isLoading = false;
        });
        return;
      }

      // 2. Kirim request ke my-tickets (BUKAN all lagi)
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8080/api/tickets/my-tickets'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;

        int active = 0;
        int resolved = 0;

        for (var t in data) {
          String status = (t['status']?.toString() ?? 'OPEN')
              .trim()
              .toUpperCase();

          if (status == 'OPEN' ||
              status == 'IN PROGRESS' ||
              status == 'IN_PROGRESS') {
            active++;
          } else if (status == 'RESOLVED' ||
              status == 'CLOSED' ||
              status == 'DONE') {
            resolved++;
          }
        }

        setState(() {
          _tickets = data;
          _activeTicketsCount = active;
          _resolvedTicketsCount = resolved;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Gagal memuat API (Status: ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Koneksi Ditolak/Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: mintGreen))
            : SingleChildScrollView(
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
                    _buildTicketContent(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
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

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: navySlate,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: const TextStyle(color: greyText, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _userName,
                  style: const TextStyle(
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
                'Live Update',
                style: TextStyle(
                  color: navySlate.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$_activeTicketsCount Active Ticket${_activeTicketsCount != 1 ? 's' : ''}',
            style: const TextStyle(
              color: navySlate,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _activeTicketsCount > 0
                ? 'Assigned to technical engineering\nqueue for immediate action.'
                : 'All systems operational.\nNo active issues currently.',
            style: TextStyle(
              color: navySlate.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard('TOTAL TIKET', _tickets.length.toString()),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'TIKET SELESAI',
            _resolvedTicketsCount.toString(),
          ),
        ),
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
        GestureDetector(
          onTap: _fetchTicketsData,
          child: Row(
            children: [
              const Icon(Icons.refresh, size: 16, color: mintGreen),
              const SizedBox(width: 4),
              Text(
                'Refresh',
                style: TextStyle(
                  color: mintGreen.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTicketContent() {
    if (_errorMessage.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_tickets.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Icon(Icons.inbox_outlined, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Belum ada tiket yang terbuat',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _tickets.length,
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        final String id = ticket['ticketId']?.toString() ?? '-';
        final String status =
            ticket['status']?.toString().toUpperCase() ?? 'OPEN';
        final String title =
            ticket['description']?.toString() ??
            ticket['problem']?.toString() ??
            'Tidak ada detail';
        final String time = ticket['createdAt']?.toString() ?? 'Baru saja';

        Color sColor = mintGreen;
        Color sBgColor = mintGreen.withValues(alpha: 0.1);
        if (status == 'OPEN') {
          sColor = const Color(0xFFFF5252);
          sBgColor = const Color(0xFFFF5252).withValues(alpha: 0.1);
        } else if (status == 'IN PROGRESS' || status == 'IN_PROGRESS') {
          sColor = const Color(0xFF448AFF);
          sBgColor = const Color(0xFF448AFF).withValues(alpha: 0.1);
        }

        return Column(
          children: [
            _buildTicketItem(
              id: id,
              status: status,
              title: title,
              category: 'IT Support',
              time: time,
              statusColor: sColor,
              statusBgColor: sBgColor,
            ),
            if (index < _tickets.length - 1) const SizedBox(height: 16),
          ],
        );
      },
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
    // DIBUNGKUS GESTURE DETECTOR AGAR BISA DIKLIK
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Membuka detail tiket #$id...'),
            backgroundColor: mintGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
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
                      time.length > 10 ? time.substring(0, 10) : time,
                      style: const TextStyle(color: greyText, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
