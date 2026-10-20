import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chat_screen.dart'; // Import untuk memanggil AI Hazel
import 'ticket_tracker_screen.dart'; // Import untuk halaman Pelacak Tiket
import 'ticket_detail_screen.dart';
import 'submit_ticket_screen.dart';
import 'settings_screen.dart';
import 'faq_screen.dart';
import 'notification_screen.dart';
import 'ticket_chat_screen.dart';
import 'announcements_screen.dart';
import 'knowledge_base_screen.dart';
import 'my_assets_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _userName = "Pengguna";
  late Future<List<dynamic>> _ticketsFuture;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _ticketsFuture = fetchTickets();
    _fetchUnreadCount();
  }

  Future<List<dynamic>> fetchTickets() async {
    try {
      // 1. Panggil brankas memori untuk mengambil token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      // PENGECEKAN TOKEN: Menghilangkan garis merah Null Safety
      if (token == null || token.isEmpty) {
        debugPrint(
          'Dashboard: Token tidak ditemukan, tidak bisa memuat tiket.',
        );
        return [];
      }

      // 2. Tembakkan request ke my-tickets (bukan all lagi)
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8080/api/tickets/my-tickets'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        debugPrint('Dashboard API Error: Status ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching tickets: $e');
      return [];
    }
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
      return 'greeting_morning'.tr();
    } else if (hour < 15) {
      return 'greeting_afternoon'.tr();
    } else if (hour < 18) {
      return 'greeting_evening'.tr();
    } else {
      return 'greeting_night'.tr();
    }
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null || token.isEmpty) return;

      final response = await http.get(
        Uri.parse('http://10.0.2.2:8080/api/notifications'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final unread = data.where((n) {
          return n['isRead'] != true && n['read'] != true;
        }).length;

        if (mounted) {
          setState(() {
            _unreadNotificationCount = unread;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching unread notification count: $e');
    }
  }

  Future<void> _refreshTickets() async {
    setState(() {
      _ticketsFuture = fetchTickets();
    });
    _fetchUnreadCount();
    await _ticketsFuture;
  }

  void _showInDevelopmentSnackBar() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('feature_in_development'.tr()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _launchWhatsAppSupport() async {
    const phoneNumber = '6281234567890';
    final message = Uri.encodeComponent(
      'Halo Tim IT Support, saya butuh bantuan terkait...',
    );
    final url = Uri.parse('https://wa.me/$phoneNumber?text=$message');

    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka WhatsApp. Pastikan aplikasi terpasang.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka WhatsApp: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Buka Live Chat: cari tiket aktif pertama lalu buka ruang obrolan.
  /// Jika tidak ada tiket aktif, arahkan pengguna ke Buat/Lacak Tiket.
  void _openLiveChat() async {
    try {
      final tickets = await _ticketsFuture;

      // Cari tiket aktif (OPEN atau IN_PROGRESS)
      Map<String, dynamic>? activeTicket;
      for (var t in tickets) {
        final status = (t['currentStatus']?.toString() ??
                t['status']?.toString() ??
                'OPEN')
            .trim()
            .toUpperCase();
        if (status == 'OPEN' ||
            status == 'IN_PROGRESS' ||
            status == 'IN PROGRESS') {
          activeTicket = t;
          break;
        }
      }

      if (!mounted) return;

      if (activeTicket != null) {
        final ticketId = activeTicket['ticketId']?.toString() ??
            activeTicket['id']?.toString() ??
            '';
        final ticketDesc = activeTicket['description']?.toString() ??
            activeTicket['problem']?.toString();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TicketChatScreen(
              ticketId: ticketId,
              ticketCode: ticketId,
              ticketTitle: ticketDesc,
            ),
          ),
        );
      } else {
        // Tidak ada tiket aktif – beri notifikasi
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Tidak ada tiket aktif. Silakan buat tiket baru terlebih dahulu.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Buat Tiket',
              textColor: Colors.white,
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubmitTicketScreen(),
                  ),
                );
                if (result == true && mounted) {
                  _refreshTickets();
                }
              },
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memuat tiket. Silakan coba lagi.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        color: const Color(0xFF48CEA4),
        onRefresh: _refreshTickets,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderAndQuickActions(context),
              const SizedBox(height: 20),
              _buildCorporateServices(),
              const SizedBox(height: 16),
              _buildNotificationCard(),
              const SizedBox(height: 16),
              _buildRecentTickets(),
              const SizedBox(height: 16),
              _buildPromoBanner(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAndQuickActions(BuildContext context) {
    return SizedBox(
      height: 310,
      child: Stack(
        children: [
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
                  Colors.white.withValues(alpha: 0.15),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'greeting_hi'.tr(args: [_userName]),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Badge.count(
                            count: _unreadNotificationCount,
                            isLabelVisible: _unreadNotificationCount > 0,
                            backgroundColor: const Color(0xFFFF5252),
                            textColor: Colors.white,
                            child: IconButton(
                              icon: const Icon(
                                Icons.notifications_none,
                                color: Colors.white,
                              ),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const NotificationScreen(),
                                  ),
                                );
                                if (mounted) {
                                  _fetchUnreadCount();
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                          },
                          child: const CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.person, color: Color(0xFF1E293B)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
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
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildQuickAction(
                    context,
                    icon: Icons.chat_bubble_outline,
                    label: 'ai_chat'.tr(),
                    isActive: true,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChatScreen(),
                        ),
                      );
                      if (mounted) {
                        _refreshTickets();
                      }
                    },
                  ),
                  _buildQuickAction(
                    context,
                    icon: Icons.analytics_outlined,
                    label: 'track_ticket'.tr(),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TicketTrackerScreen(),
                        ),
                      );
                      if (mounted) {
                        _refreshTickets();
                      }
                    },
                  ),
                  _buildQuickAction(
                    context,
                    icon: Icons.phone_outlined,
                    label: 'call_support'.tr(),
                    onTap: _launchWhatsAppSupport,
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

  Widget _buildCorporateServices() {
    final List<Map<String, dynamic>> services = [
      {
        'icon': Icons.menu_book,
        'title': 'knowledge_base'.tr(),
      },
      {
        'icon': Icons.add_circle_outline,
        'title': 'submit_ticket'.tr(),
      },
      {
        'icon': Icons.chat_bubble_outline,
        'title': 'live_chat'.tr(),
      },
      {
        'icon': Icons.devices_outlined,
        'title': 'my_assets'.tr(),
      },
      {
        'icon': Icons.layers_outlined,
        'title': 'service_catalog'.tr(),
      },
      {
        'icon': Icons.campaign_outlined,
        'title': 'announcements'.tr(),
      },
      {
        'icon': Icons.quiz_outlined,
        'title': 'faq'.tr(),
      },
      {
        'icon': Icons.settings_outlined,
        'title': 'settings'.tr(),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'corporate_services'.tr(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.85,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              final isSubmitTicket =
                  service['icon'] == Icons.add_circle_outline;
              final isSettings =
                  service['icon'] == Icons.settings_outlined;
              final isLiveChat =
                  service['icon'] == Icons.chat_bubble_outline;
              final isKnowledgeBase =
                  service['icon'] == Icons.menu_book;
              final isAnnouncements =
                  service['icon'] == Icons.campaign_outlined;
              final isMyAssets =
                  service['icon'] == Icons.devices_outlined;
              final isFaq =
                  service['icon'] == Icons.quiz_outlined;

              return GestureDetector(
                onTap: isSubmitTicket
                    ? () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SubmitTicketScreen(),
                          ),
                        );
                        if (result == true && mounted) {
                          _refreshTickets();
                        }
                      }
                    : isSettings
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                          }
                        : isLiveChat
                            ? () => _openLiveChat()
                            : isKnowledgeBase
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const KnowledgeBaseScreen(),
                                      ),
                                    );
                                  }
                                : isAnnouncements
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const AnnouncementsScreen(),
                                          ),
                                        );
                                      }
                                    : isMyAssets
                                        ? () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const MyAssetsScreen(),
                                              ),
                                            );
                                          }
                                        : isFaq
                                            ? () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const FaqScreen(),
                                                  ),
                                                );
                                              }
                                            : _showInDevelopmentSnackBar,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF48CEA4).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          service['icon'],
                          color: const Color(0xFF48CEA4),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        service['title'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard() {
    return FutureBuilder<List<dynamic>>(
      future: _ticketsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        Map<String, dynamic>? latestResolvedTicket;
        for (var t in snapshot.data!) {
          String status = (t['status']?.toString() ?? 'OPEN')
              .trim()
              .toUpperCase();
          if (status == 'RESOLVED' || status == 'CLOSED' || status == 'DONE') {
            latestResolvedTicket = t;
            break;
          }
        }

        if (latestResolvedTicket == null) {
          return const SizedBox.shrink();
        }

        final resolvedId =
            latestResolvedTicket['ticketId']?.toString() ??
            latestResolvedTicket['id']?.toString() ??
            '-';

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ticket_resolved'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ticket_resolved_update'.tr(args: [resolvedId]),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentTickets() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'recent_tickets'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _ticketsFuture = fetchTickets();
                  });
                },
                child: Row(
                  children: [
                    const Icon(Icons.refresh, size: 16, color: Color(0xFF48CEA4)),
                    const SizedBox(width: 4),
                    Text(
                      'refresh'.tr(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF48CEA4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<dynamic>>(
            future: _ticketsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(color: Color(0xFF48CEA4)),
                  ),
                );
              }

              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
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
                  child: Column(
                    children: [
                      const Icon(Icons.inbox_outlined, size: 40, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        'no_recent_tickets'.tr(),
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              final tickets = snapshot.data!;
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tickets.length,
                itemBuilder: (context, index) {
                  return _buildTicketCard(tickets[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final String id =
        ticket['ticketId']?.toString() ?? ticket['id']?.toString() ?? '-';
    final String problem =
        ticket['problem']?.toString() ??
        ticket['description']?.toString() ??
        'no_description'.tr();

    final String status = (ticket['currentStatus']?.toString() ??
            ticket['status']?.toString() ??
            'OPEN')
        .trim()
        .toUpperCase();

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'OPEN':
        statusColor = const Color(0xFF3B82F6);
        statusIcon = Icons.fiber_new;
        break;
      case 'IN_PROGRESS':
      case 'IN PROGRESS':
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.autorenew;
        break;
      case 'RESOLVED':
      case 'CLOSED':
      case 'DONE':
        statusColor = const Color(0xFF48CEA4);
        statusIcon = Icons.check_circle_outline;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    final dynamic rawDate = ticket['createdAt'] ??
        ticket['created_at'] ??
        ticket['report_date'] ??
        ticket['reportDate'] ??
        ticket['created_date'] ??
        ticket['date'] ??
        ticket['timestamp'];

    String formattedDate = '';
    if (rawDate != null && rawDate.toString().trim().isNotEmpty) {
      final dateStr = rawDate.toString().trim();
      try {
        final dt = DateTime.parse(dateStr).toLocal();
        formattedDate =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        formattedDate = dateStr;
      }
    }

    if (formattedDate.isEmpty) {
      final now = DateTime.now();
      formattedDate =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }

    // KARTU TIKET SEKARANG DIBUNGKUS GESTURE DETECTOR AGAR BISA DIKLIK
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TicketDetailScreen(
              ticketId: id,
              problem: problem,
              status: status,
              createdAt: formattedDate,
              ticketData: ticket,
            ),
          ),
        );
        if (mounted) {
          _refreshTickets();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
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
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#$id',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    problem,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formattedDate,
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'rate_our_service'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'rate_service_desc'.tr(),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF48CEA4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'rate_now'.tr(),
                style: const TextStyle(
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
