import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_screen.dart'; // Import untuk memanggil AI Hazel
import 'ticket_tracker_screen.dart'; // Import untuk halaman Pelacak Tiket

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _userName = "Pengguna";

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? "Pengguna";
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) {
      return "Selamat pagi,";
    } else if (hour < 15) {
      return "Selamat siang,";
    } else if (hour < 18) {
      return "Selamat sore,";
    } else {
      return "Selamat malam,";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Latar abu-abu sangat terang
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderAndQuickActions(context),
            const SizedBox(height: 20),
            _buildCorporateServices(),
            const SizedBox(height: 16),
            _buildNotificationCard(),
            const SizedBox(height: 16),
            _buildPromoBanner(),
            const SizedBox(height: 40), // Spasi bawah
          ],
        ),
      ),
    );
  }

  // --- KOMPONEN 1: Header Mint Green dengan Ornamen & Kartu Quick Action ---
  Widget _buildHeaderAndQuickActions(BuildContext context) {
    return SizedBox(
      height: 310, // Total tinggi area header + kartu melayang
      child: Stack(
        children: [
          // Background Header dengan Ornamen Aset
          Container(
            height: 250,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF48CEA4), Color(0xFF38B28B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              image: DecorationImage(
                image: const AssetImage('assets/images/header_pattern.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.white.withValues(
                    alpha: 0.15,
                  ), // Mengatur transparansi ornamen
                  BlendMode.dstATop,
                ),
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Teks Sapaan
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hai, $_userName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    // Ikon Notifikasi & Profil
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.notifications_none,
                              color: Colors.white,
                            ),
                            onPressed: () {},
                          ),
                        ),
                        const SizedBox(width: 12),
                        const CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Kartu Melayang (Quick Actions)
          Positioned(
            top: 180,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuickAction(
                    context,
                    icon: Icons.chat_bubble_outline,
                    label: 'AI Chat',
                    isActive: true, // Warna Mint
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChatScreen(),
                        ),
                      );
                    },
                  ),
                  // PENGUBAHAN TOMBOL TRACK TICKET DI SINI
                  _buildQuickAction(
                    context,
                    icon: Icons.analytics_outlined,
                    label: 'Track Ticket',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TicketTrackerScreen(),
                        ),
                      );
                    },
                  ),
                  _buildQuickAction(
                    context,
                    icon: Icons.help_outline,
                    label: 'FAQ',
                    onTap: () {},
                  ),
                  _buildQuickAction(
                    context,
                    icon: Icons.phone_outlined,
                    label: 'Call Support',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF48CEA4).withValues(alpha: 0.1)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive
                  ? const Color(0xFF48CEA4)
                  : const Color(0xFF1E293B),
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  // --- KOMPONEN 2: Grid Layanan Perusahaan ---
  Widget _buildCorporateServices() {
    final List<Map<String, dynamic>> services = [
      {
        'icon': Icons.menu_book,
        'title': 'Knowledge\nBase',
        'subtitle': 'Read help...',
      },
      {
        'icon': Icons.add_circle_outline,
        'title': 'Submit\nTicket',
        'subtitle': 'File a new i...',
      },
      {
        'icon': Icons.chat_bubble_outline,
        'title': 'Live Chat',
        'subtitle': 'Talk with s...',
      },
      {
        'icon': Icons.email_outlined,
        'title': 'Email\nSupport',
        'subtitle': 'Send us a...',
      },
      {
        'icon': Icons.layers_outlined,
        'title': 'Service\nCatalog',
        'subtitle': 'Request h...',
      },
      {
        'icon': Icons.campaign_outlined,
        'title': 'Announc\nements',
        'subtitle': 'System sta...',
      },
      {
        'icon': Icons.favorite_border,
        'title': 'Feedback',
        'subtitle': 'Tell us your...',
      },
      {
        'icon': Icons.settings_outlined,
        'title': 'Settings',
        'subtitle': 'App config...',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Corporate Services',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), // Scroll mengikuti halaman utama
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.65, // Mengatur tinggi tiap kotak grid
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: services.length,
            itemBuilder: (context, index) {
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      services[index]['icon'],
                      color: const Color(0xFF48CEA4),
                      size: 24,
                    ),
                    const Spacer(),
                    Text(
                      services[index]['title'],
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      services[index]['subtitle'],
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- KOMPONEN 3: Kartu Status Tiket (Notifikasi) ---
  Widget _buildNotificationCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Garis hijau vertikal
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF48CEA4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF48CEA4).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Color(0xFF48CEA4),
                size: 18,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ticket Resolved',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Update: Ticket #TKT-123 is Resolved',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // --- KOMPONEN 4: Banner Promosi ---
  Widget _buildPromoBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B), // Navy Slate
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star_border, color: Color(0xFF48CEA4)),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rate our Service',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Help us improve the IT desk',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF48CEA4), // Mint Green
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Rate Now',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
