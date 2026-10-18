import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Layar Live Chat per-tiket.
/// Menampilkan percakapan antara pengguna dan teknisi dalam bubble chat.
class TicketChatScreen extends StatefulWidget {
  final String ticketId;
  final String? ticketCode;
  final String? ticketTitle;

  const TicketChatScreen({
    super.key,
    required this.ticketId,
    this.ticketCode,
    this.ticketTitle,
  });

  @override
  State<TicketChatScreen> createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends State<TicketChatScreen> {
  // ── Konstanta warna ────────────────────────────────────────
  static const Color _mintGreen = Color(0xFF48CEA4);
  static const Color _navySlate = Color(0xFF1E293B);
  static const Color _greyText = Color(0xFF94A3B8);

  // ── State ──────────────────────────────────────────────────
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String _errorMessage = '';

  // Info user saat ini (dari SharedPreferences)
  String _currentUserName = '';
  String _currentUserRole = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _fetchMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Muat info user dari SharedPreferences ──────────────────
  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentUserName = prefs.getString('user_name') ?? 'Pengguna';
        _currentUserRole = prefs.getString('user_role') ?? 'USER';
      });
    }
  }

  // ── Helper: ambil token bersih ─────────────────────────────
  Future<String> _getCleanToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    if (token.startsWith('Bearer ')) {
      return token.substring(7).trim();
    }
    return token.trim();
  }

  // ── Fetch pesan dari API ───────────────────────────────────
  Future<void> _fetchMessages() async {
    setState(() {
      _isLoading = _messages.isEmpty; // hanya tampilkan loading saat pertama
      _errorMessage = '';
    });

    try {
      final token = await _getCleanToken();
      if (token.isEmpty) {
        setState(() {
          _errorMessage = 'Sesi login tidak valid. Silakan login ulang.';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(
          'http://10.0.2.2:8080/api/tickets/${widget.ticketId}/messages',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic rawData = jsonDecode(response.body);
        List<dynamic> list = [];
        if (rawData is List) {
          list = rawData;
        } else if (rawData is Map && rawData['data'] is List) {
          list = rawData['data'];
        }

        final parsed = list.map<Map<String, dynamic>>((m) {
          return {
            'id': m['id']?.toString() ?? '',
            'message': m['message']?.toString() ?? '',
            'senderName': m['senderName']?.toString() ?? 'Unknown',
            'senderEmail': m['senderEmail']?.toString() ?? '',
            'senderRole': m['senderRole']?.toString() ?? '',
            'createdAt': m['createdAt']?.toString() ?? '',
          };
        }).toList();

        if (mounted) {
          setState(() {
            _messages = parsed;
            _isLoading = false;
          });
          _scrollToBottom();
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Gagal memuat pesan (HTTP ${response.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Terjadi kesalahan jaringan: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ── Kirim pesan ke API ─────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final token = await _getCleanToken();
      if (token.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sesi login tidak valid. Silakan login ulang.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        setState(() => _isSending = false);
        return;
      }

      final response = await http.post(
        Uri.parse(
          'http://10.0.2.2:8080/api/tickets/${widget.ticketId}/messages',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'message': text}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _messageController.clear();
        await _fetchMessages();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gagal mengirim pesan (HTTP ${response.statusCode})',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kesalahan jaringan: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  // ── Auto-scroll ke bawah ───────────────────────────────────
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Apakah pesan dari user saat ini? ───────────────────────
  bool _isFromCurrentUser(Map<String, dynamic> msg) {
    // Cocokkan berdasarkan nama ATAU role
    final senderName = msg['senderName']?.toString() ?? '';
    final senderRole = msg['senderRole']?.toString().toUpperCase() ?? '';

    if (senderName == _currentUserName) return true;
    if (senderRole == _currentUserRole.toUpperCase()) return true;
    return false;
  }

  // ── Format waktu ───────────────────────────────────────────
  String _formatTime(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return rawDate;
    }
  }

  String _formatDateSeparator(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day) {
        return 'Hari ini';
      }
      final yesterday = now.subtract(const Duration(days: 1));
      if (dt.year == yesterday.year &&
          dt.month == yesterday.month &&
          dt.day == yesterday.day) {
        return 'Kemarin';
      }
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final chatTitle =
        'Chat Tiket #${widget.ticketCode ?? widget.ticketId}';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: _mintGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chatTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (widget.ticketTitle != null && widget.ticketTitle!.isNotEmpty)
              Text(
                widget.ticketTitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Segarkan Pesan',
            onPressed: _fetchMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── List Pesan ──────────────────────────────────────
          Expanded(child: _buildMessageList()),

          // ── Input Bar ──────────────────────────────────────
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── List pesan ─────────────────────────────────────────────
  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _mintGreen),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _mintGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba Lagi'),
                onPressed: _fetchMessages,
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 56,
                color: _greyText.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Belum ada pesan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _navySlate,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Mulai percakapan dengan mengirim pesan pertama.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _greyText),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isMe = _isFromCurrentUser(msg);

        // Tampilkan pemisah tanggal jika berbeda dari pesan sebelumnya
        Widget? dateSeparator;
        final currentDate = _formatDateSeparator(msg['createdAt']);
        if (index == 0) {
          dateSeparator = _buildDateSeparator(currentDate);
        } else {
          final prevDate =
              _formatDateSeparator(_messages[index - 1]['createdAt']);
          if (currentDate != prevDate) {
            dateSeparator = _buildDateSeparator(currentDate);
          }
        }

        return Column(
          children: [
            ?dateSeparator,
            _buildChatBubble(msg, isMe),
          ],
        );
      },
    );
  }

  // ── Pemisah tanggal ────────────────────────────────────────
  Widget _buildDateSeparator(String label) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: _greyText.withValues(alpha: 0.3),
              thickness: 0.5,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _greyText.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: _greyText.withValues(alpha: 0.3),
              thickness: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bubble chat ────────────────────────────────────────────
  Widget _buildChatBubble(Map<String, dynamic> msg, bool isMe) {
    final senderName = msg['senderName'] ?? 'Unknown';
    final message = msg['message'] ?? '';
    final time = _formatTime(msg['createdAt']);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isMe ? 48 : 0,
          right: isMe ? 0 : 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? _mintGreen : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Nama pengirim (hanya untuk pihak lawan)
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _mintGreen.withValues(alpha: 0.9),
                  ),
                ),
              ),
            // Isi pesan
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: isMe ? Colors.white : _navySlate,
                height: 1.4,
              ),
            ),
            // Waktu
            if (time.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : _greyText,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Input bar ──────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                style: const TextStyle(fontSize: 14, color: _navySlate),
                decoration: const InputDecoration(
                  hintText: 'Tulis pesan...',
                  hintStyle: TextStyle(color: _greyText, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: _mintGreen,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _isSending ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
