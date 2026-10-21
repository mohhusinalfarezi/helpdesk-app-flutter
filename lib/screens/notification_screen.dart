import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ticket_detail_screen.dart';
import 'package:helpdesk_app/config/api_config.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color mintGreen = Color(0xFF48CEA4);
  static const Color navySlate = Color(0xFF1E293B);
  static const Color greyText = Color(0xFF94A3B8);

  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  // ── Ambil notifikasi dari API ───────────────────────────────
  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = 'session_invalid'.tr();
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/notifications'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _notifications = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'api_load_failed'.tr(args: [response.statusCode.toString()]);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'connection_error'.tr(args: [e.toString()]);
        _isLoading = false;
      });
    }
  }

  // ── Tandai notifikasi sudah dibaca (PUT) ─────────────────────
  Future<void> _markAsRead(dynamic item, int index) async {
    final dynamic rawId = item['id'] ?? item['notificationId'];
    if (rawId == null) return;

    // Optimistic update pada UI
    final bool wasRead = item['isRead'] == true || item['read'] == true;
    if (!wasRead) {
      setState(() {
        _notifications[index]['isRead'] = true;
        _notifications[index]['read'] = true;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null || token.isEmpty) return;

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/notifications/$rawId/read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200 && !wasRead) {
        // Rollback jika request gagal
        if (mounted) {
          setState(() {
            _notifications[index]['isRead'] = false;
            _notifications[index]['read'] = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      if (!wasRead && mounted) {
        setState(() {
          _notifications[index]['isRead'] = false;
          _notifications[index]['read'] = false;
        });
      }
    }
  }

  // ── Helper ambil ID tiket terkait ───────────────────────────
  String? _extractRelatedTicketId(dynamic item) {
    final dynamic rawRelatedId = item['relatedId'] ??
        item['ticketId'] ??
        item['ticket_id'] ??
        item['referenceId'];
    if (rawRelatedId != null && rawRelatedId.toString().trim().isNotEmpty) {
      return rawRelatedId.toString().trim();
    }

    // Ekstraksi fallback dari judul atau pesan (misal: "Tiket #10" atau "#10")
    final String text = '${item['title'] ?? ''} ${item['message'] ?? ''}';
    final match = RegExp(r'#(\d+)').firstMatch(text);
    if (match != null) {
      return match.group(1);
    }

    return null;
  }

  // ── Helper cek notifikasi bertipe tiket ──────────────────────
  bool _isTicketNotification(dynamic item) {
    final String type = (item['type']?.toString() ?? '').trim().toUpperCase();
    if (type.contains('TICKET')) return true;
    final relatedId = _extractRelatedTicketId(item);
    return relatedId != null && relatedId.isNotEmpty;
  }

  // ── Aksi saat kartu notifikasi diklik ───────────────────────
  Future<void> _handleNotificationTap(dynamic item, int index) async {
    // 1. Tandai telah dibaca
    _markAsRead(item, index);

    // 2. Ambil nilai relatedId dan cek tipe tiket
    final String? relatedId = _extractRelatedTicketId(item);
    final bool isTicket = _isTicketNotification(item);

    // 3. Jika terkait tiket, lakukan navigasi ke TicketDetailScreen
    if (relatedId != null && relatedId.isNotEmpty && isTicket) {
      final String title = item['title']?.toString() ??
          item['subject']?.toString() ??
          'Tiket #$relatedId';
      final String message = item['message']?.toString() ??
          item['content']?.toString() ??
          item['body']?.toString() ??
          title;
      final dynamic rawDate = item['createdAt'] ??
          item['created_at'] ??
          item['timestamp'] ??
          item['date'];
      final String formattedDate = _formatDateTime(rawDate);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TicketDetailScreen(
            ticketId: relatedId,
            problem: message.isNotEmpty ? message : title,
            status: 'OPEN',
            createdAt: formattedDate.isNotEmpty ? formattedDate : '-',
          ),
        ),
      );

      // Refresh data notifikasi setelah kembali
      if (mounted) {
        _fetchNotifications();
      }
    }
  }

  // ── Helper format waktu ────────────────────────────────────
  String _formatDateTime(dynamic rawDate) {
    if (rawDate == null) return '';
    try {
      final dt = DateTime.parse(rawDate.toString().trim()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return rawDate.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) {
      return n['isRead'] != true && n['read'] != true;
    }).length;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'notifications'.tr(),
          style: const TextStyle(
            color: navySlate,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: navySlate,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: mintGreen, size: 20),
            tooltip: 'refresh'.tr(),
            onPressed: _fetchNotifications,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: mintGreen))
            : RefreshIndicator(
                color: mintGreen,
                onRefresh: _fetchNotifications,
                child: _buildBody(unreadCount),
              ),
      ),
    );
  }

  Widget _buildBody(int unreadCount) {
    if (_errorMessage.isNotEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.error_outline,
                    size: 44, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _fetchNotifications,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mintGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('refresh'.tr()),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: mintGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_off_outlined,
                    size: 48,
                    color: mintGreen,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'no_notifications'.tr(),
                  style: const TextStyle(
                    color: navySlate,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'no_notifications_desc'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: greyText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final item = _notifications[index];
        final bool isRead = item['isRead'] == true || item['read'] == true;
        final String title = item['title']?.toString() ??
            item['subject']?.toString() ??
            'notifications'.tr();
        final String message = item['message']?.toString() ??
            item['content']?.toString() ??
            item['body']?.toString() ??
            '';
        final dynamic rawDate = item['createdAt'] ??
            item['created_at'] ??
            item['timestamp'] ??
            item['date'];
        final String formattedDate = _formatDateTime(rawDate);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildNotificationCard(
            item: item,
            index: index,
            isRead: isRead,
            title: title,
            message: message,
            formattedDate: formattedDate,
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard({
    required dynamic item,
    required int index,
    required bool isRead,
    required String title,
    required String message,
    required String formattedDate,
  }) {
    final Color cardBgColor =
        isRead ? Colors.white : mintGreen.withValues(alpha: 0.08);
    final Color borderColor = isRead
        ? Colors.grey.withValues(alpha: 0.12)
        : mintGreen.withValues(alpha: 0.4);

    final bool hasTicketDetail =
        _isTicketNotification(item) && _extractRelatedTicketId(item) != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleNotificationTap(item, index),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: isRead ? 1 : 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon notifikasi
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isRead
                      ? Colors.grey.withValues(alpha: 0.1)
                      : mintGreen.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRead
                      ? Icons.notifications_none
                      : Icons.notifications_active,
                  color: isRead ? greyText : mintGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),

              // Konten teks
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: navySlate,
                              fontSize: 14,
                              fontWeight:
                                  isRead ? FontWeight.w600 : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: const BoxDecoration(
                              color: mintGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: TextStyle(
                          color: isRead
                              ? const Color(0xFF64748B)
                              : const Color(0xFF334155),
                          fontSize: 13,
                          height: 1.4,
                          fontWeight:
                              isRead ? FontWeight.normal : FontWeight.w500,
                        ),
                      ),
                    ],
                    if (formattedDate.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: greyText.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              color: greyText.withValues(alpha: 0.8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (hasTicketDetail)
                const Padding(
                  padding: EdgeInsets.only(left: 8.0, top: 4.0),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: greyText,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
