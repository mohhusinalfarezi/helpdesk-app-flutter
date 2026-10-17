import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // Wajib ditambahkan untuk ambil token

import 'ticket_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Color Palette
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color mintGreen = Color(0xFF48CEA4);
  static const Color navySlate = Color(0xFF1E293B);
  static const Color greyText = Color(0xFF94A3B8); // Slate 400
  static const Color inputBgColor = Color(0xFFF1F5F9);

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Variabel untuk fitur gambar dan loading
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _isTyping = false;

  // Riwayat percakapan persisten antar-lifecycle widget
  static final List<Map<String, dynamic>> _chatHistory = [
    {
      'text':
          'Halo! Saya Hazel, asisten AI IT Helpdesk. Ada kendala teknis yang bisa saya bantu hari ini?',
      'isUser': false,
      'time': 'Sekarang',
      'imagePath': null,
    },
  ];

  List<Map<String, dynamic>> get messages => _chatHistory;

  @override
  void initState() {
    super.initState();
    _scrollToBottom();
  }

  // 1. Fungsi memilih gambar dari Galeri HP/Emulator
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // 2. Fungsi mengunggah gambar ke Spring Boot (Multipart)
  Future<String?> _uploadImageToBackend(File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:8080/api/upload'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        return data['imageUrl']; // URL gambar dari server
      }
    } catch (e) {
      debugPrint('Gagal mengunggah gambar: $e');
    }
    return null;
  }

  // 3. Fungsi Utama Mengirim Pesan (Teks + Gambar) dengan JWT Token
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    final String currentTime = TimeOfDay.now().format(context);
    File? imageToUpload = _selectedImage;

    // Tampilkan pesan pengguna di layar langsung
    setState(() {
      messages.add({
        'text': text,
        'isUser': true,
        'time': currentTime,
        'imagePath':
            imageToUpload?.path, // Path lokal untuk preview di chat bubble
      });
      _selectedImage = null; // Kosongkan preview di atas kolom input
      _isLoading = true;
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // Upload gambar jika ada
    String? imageUrl;
    if (imageToUpload != null) {
      imageUrl = await _uploadImageToBackend(imageToUpload);
    }

    // Tembak API Chat Spring Boot
    try {
      // 👇 AMBIL TOKEN DARI MEMORI 👇
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('http://10.0.2.2:8080/api/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer $token', // 👇 SISIPKAN TOKEN KE DALAM HEADER 👇
        },
        body: jsonEncode({
          'message': text,
          'ticketId': '', // Kosongkan sementara
          'imageUrl': imageUrl, // Kirim URL gambar jika ada
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final botReply = responseData['reply'] ??
            responseData['message'] ??
            responseData['response'] ??
            'Maaf, terjadi kesalahan.';

        final bool shouldEscalate = responseData['shouldEscalate'] == true ||
            responseData['shouldEscalate']?.toString().toLowerCase() == 'true';
        final String? suggestedCategory =
            responseData['suggestedCategory']?.toString();
        final String? suggestedSummary =
            responseData['suggestedSummary']?.toString();

        setState(() {
          messages.add({
            'text': botReply,
            'isUser': false,
            'time': TimeOfDay.now().format(context),
            'imagePath': null,
            'shouldEscalate': shouldEscalate,
            'suggestedCategory': suggestedCategory,
            'suggestedSummary': suggestedSummary,
            'ticketCreated': false,
            'ticketId': null,
            'isCreatingTicket': false,
          });
        });
      } else {
        _showError("Gagal menghubungi Hazel (Error ${response.statusCode}).");
      }
    } catch (e) {
      _showError(
        "Tidak dapat terhubung ke server. Pastikan Spring Boot menyala.",
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  void _showError(String errorMsg) {
    setState(() {
      messages.add({
        'text': errorMsg,
        'isUser': false,
        'time': TimeOfDay.now().format(context),
        'imagePath': null,
      });
    });
  }

  // ── Fungsi membuat tiket otomatis dari tawaran eskalasi ──────
  Future<void> _createTicketFromEscalation(
      Map<String, dynamic> message, int index) async {
    if (message['isCreatingTicket'] == true ||
        message['ticketCreated'] == true) {
      return;
    }

    setState(() {
      message['isCreatingTicket'] = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null || token.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sesi login tidak valid. Silakan login ulang.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() {
            message['isCreatingTicket'] = false;
          });
        }
        return;
      }

      final cleanToken = token.startsWith('Bearer ')
          ? token.substring(7).trim()
          : token.trim();

      final String category =
          message['suggestedCategory']?.toString().trim() ?? 'General IT';
      final String summary =
          message['suggestedSummary']?.toString().trim() ??
              message['text']?.toString().trim() ??
              'Keluhan dari AI Chat';

      // Mapping nama kategori ke categoryId jika diperlukan oleh backend
      String categoryId = '4'; // Default: General IT
      final lowerCat = category.toLowerCase();
      if (lowerCat.contains('hard')) {
        categoryId = '1';
      } else if (lowerCat.contains('soft')) {
        categoryId = '2';
      } else if (lowerCat.contains('net') || lowerCat.contains('jaring')) {
        categoryId = '3';
      } else if (int.tryParse(category) != null) {
        categoryId = category;
      }

      final response = await http.post(
        Uri.parse('http://10.0.2.2:8080/api/tickets'),
        headers: {
          'Authorization': 'Bearer $cleanToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'description': summary,
          'categoryId': categoryId,
          'category': category,
          'problem': summary,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        String? ticketId;
        try {
          final resData = jsonDecode(response.body);
          if (resData is Map) {
            final rawId = resData['ticketId'] ??
                resData['id'] ??
                (resData['ticket'] is Map
                    ? (resData['ticket']['ticketId'] ?? resData['ticket']['id'])
                    : null);
            if (rawId != null) ticketId = rawId.toString();
          }
        } catch (_) {}

        final String displayId =
            (ticketId != null && ticketId.isNotEmpty) ? '#$ticketId' : '';

        setState(() {
          message['isCreatingTicket'] = false;
          message['ticketCreated'] = true;
          message['ticketId'] = ticketId;

          // Tambahkan konfirmasi bubble di chat
          messages.add({
            'text': displayId.isNotEmpty
                ? 'Tiket ($displayId) berhasil dibuat otomatis! Tim teknisi akan segera menindaklanjuti keluhan Anda.'
                : 'Tiket berhasil dibuat otomatis! Tim teknisi akan segera menindaklanjuti keluhan Anda.',
            'isUser': false,
            'time': TimeOfDay.now().format(context),
            'imagePath': null,
          });
        });

        _scrollToBottom();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              displayId.isNotEmpty
                  ? 'Tiket berhasil dibuat ($displayId)! Tim teknisi akan segera menindaklanjuti.'
                  : 'Tiket berhasil dibuat! Tim teknisi akan segera menindaklanjuti.',
            ),
            backgroundColor: const Color(0xFF48CEA4),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        setState(() {
          message['isCreatingTicket'] = false;
        });

        String errorMsg = 'Gagal membuat tiket (Status ${response.statusCode})';
        try {
          final resData = jsonDecode(response.body);
          if (resData is Map && resData.containsKey('error')) {
            errorMsg = resData['error'].toString();
          } else if (resData is Map && resData.containsKey('message')) {
            errorMsg = resData['message'].toString();
          }
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          message['isCreatingTicket'] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan koneksi: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

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
    // Panggilan lanjutan setelah jeda singkat untuk layout dinamis Markdown
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Dialog Konfirmasi Mulai Obrolan Baru ───────────────────
  void _showResetChatDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Mulai Obrolan Baru?",
            style: TextStyle(
              color: navySlate,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: const Text(
            "Riwayat percakapan saat ini akan dihapus dan sesi baru akan dimulai.",
            style: TextStyle(
              color: Color(0xFF475569),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                "Batal",
                style: TextStyle(
                  color: greyText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _resetChatSession();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5252),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Hapus / Mulai Baru",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _resetChatSession() {
    setState(() {
      _chatHistory.clear();
      _chatHistory.add({
        'text':
            'Halo! Saya Hazel, asisten AI IT Helpdesk. Ada kendala teknis yang bisa saya bantu hari ini?',
        'isUser': false,
        'time': TimeOfDay.now().format(context),
        'imagePath': null,
      });
      _selectedImage = null;
      _isLoading = false;
      _isTyping = false;
    });
    _messageController.clear();
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: navySlate),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Helpdesk AI - Hazel",
          style: TextStyle(
            color: navySlate,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt, color: navySlate),
            tooltip: "Mulai Obrolan Baru",
            onPressed: _showResetChatDialog,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 4.0),
            child: CircleAvatar(
              backgroundColor: mintGreen.withValues(alpha: 0.2),
              child: const Icon(Icons.support_agent, color: mintGreen),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              itemCount:
                  messages.length + ((_isLoading || _isTyping) ? 1 : 0),
              itemBuilder: (context, index) {
                // Typing indicator as the last item
                if ((_isLoading || _isTyping) && index == messages.length) {
                  return _buildTypingIndicator();
                }
                final message = messages[index];
                return _buildMessageBubble(message, index);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, int index) {
    final bool isUser = message['isUser'] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: mintGreen,
              child: Icon(Icons.support_agent, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUser ? mintGreen : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isUser
                          ? const Radius.circular(16)
                          : const Radius.circular(4),
                      bottomRight: isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                    ),
                    boxShadow: isUser
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message['imagePath'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _buildImageWidget(message['imagePath']),
                          ),
                        ),
                      if (message['text'] != null &&
                          message['text'].toString().isNotEmpty)
                        isUser
                            ? Text(
                                message['text'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              )
                            : MarkdownBody(
                                data: message['text'].toString(),
                                selectable: true,
                                styleSheet: MarkdownStyleSheet(
                                  p: const TextStyle(
                                    color: navySlate,
                                    fontSize: 14.5,
                                    height: 1.5,
                                  ),
                                  strong: const TextStyle(
                                    color: navySlate,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                  ),
                                  em: const TextStyle(
                                    color: navySlate,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 14.5,
                                  ),
                                  listBullet: const TextStyle(
                                    color: mintGreen,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  code: TextStyle(
                                    color: const Color(0xFF0F766E),
                                    backgroundColor:
                                        mintGreen.withValues(alpha: 0.12),
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                  ),
                                  codeblockDecoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  blockquote: const TextStyle(
                                    color: greyText,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  h1: const TextStyle(
                                    color: navySlate,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                  h2: const TextStyle(
                                    color: navySlate,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  h3: const TextStyle(
                                    color: navySlate,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                    ],
                  ),
                ),
                if (!isUser && message['shouldEscalate'] == true)
                  _buildEscalationCard(message, index),
                const SizedBox(height: 6),
                Text(
                  message['time'],
                  style: const TextStyle(color: greyText, fontSize: 11),
                ),
              ],
            ),
          ),

          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: navySlate,
              child: Text(
                "MH",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Kartu Aksi Cepat Eskalasi ke Teknisi ────────────────────
  Widget _buildEscalationCard(Map<String, dynamic> message, int index) {
    final String category =
        message['suggestedCategory']?.toString().trim() ?? 'IT Support';
    final String summary =
        message['suggestedSummary']?.toString().trim() ?? '';
    final bool ticketCreated = message['ticketCreated'] == true;
    final String? ticketId = message['ticketId']?.toString();
    final bool isCreating = message['isCreatingTicket'] == true;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: mintGreen.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: mintGreen.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Judul + Tag Kategori
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: mintGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.support_agent,
                  color: Color(0xFF0F766E),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Eskalasi ke Teknisi?',
                  style: TextStyle(
                    color: navySlate,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (category.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: mintGreen.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      color: Color(0xFF0F766E),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),

          if (summary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              summary,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Tombol Aksi atau Status Tiket Berhasil
          if (ticketCreated)
            GestureDetector(
              onTap: ticketId != null
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TicketDetailScreen(
                            ticketId: ticketId,
                            problem: summary.isNotEmpty
                                ? summary
                                : 'Keluhan dari AI Chat',
                            status: 'OPEN',
                            createdAt: 'Baru saja',
                          ),
                        ),
                      );
                    }
                  : null,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: mintGreen.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: mintGreen, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ticketId != null && ticketId.isNotEmpty
                            ? 'Tiket #$ticketId Berhasil Dibuat (Lihat Detail)'
                            : 'Tiket Berhasil Dibuat',
                        style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (ticketId != null)
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Color(0xFF0F766E),
                      ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: isCreating
                    ? null
                    : () => _createTicketFromEscalation(message, index),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mintGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      mintGreen.withValues(alpha: 0.6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                icon: isCreating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.bolt, size: 16),
                label: Text(
                  isCreating ? 'Membuat Tiket...' : 'Buat Tiket Otomatis',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: mintGreen,
            child: Icon(Icons.support_agent, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const _TypingDotsIndicator(),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String path) {
    if (path.startsWith('http')) {
      return Image.network(path, height: 150, width: 200, fit: BoxFit.cover);
    } else if (path.startsWith('assets/')) {
      return Image.asset(path, height: 150, width: 200, fit: BoxFit.cover);
    } else {
      return Image.file(File(path), height: 150, width: 200, fit: BoxFit.cover);
    }
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Area Preview Gambar Terpilih
            if (_selectedImage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0, left: 12.0),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImage!,
                        height: 80,
                        width: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedImage = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Baris Input Teks & Tombol
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate, color: navySlate),
                  onPressed: _isLoading ? null : _pickImage,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: inputBgColor,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: "Type a message or issue...",
                        hintStyle: TextStyle(color: greyText, fontSize: 14),
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: _isLoading ? null : _sendMessage,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: mintGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Animasi Titik Melayang / Bouncing Typing Indicator
// ────────────────────────────────────────────────────────────
class _TypingDotsIndicator extends StatefulWidget {
  const _TypingDotsIndicator();

  @override
  State<_TypingDotsIndicator> createState() => _TypingDotsIndicatorState();
}

class _TypingDotsIndicatorState extends State<_TypingDotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double progress = (_controller.value - (index * 0.2)) % 1.0;
        final double bounce = (progress < 0.5)
            ? (progress * 2)
            : (2 - progress * 2);
        final double dy = -4.0 * bounce;

        return Transform.translate(
          offset: Offset(0, dy),
          child: Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFF48CEA4).withValues(
                alpha: 0.4 + (0.6 * bounce),
              ),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          "Hazel sedang mengetik",
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            _buildDot(1),
            _buildDot(2),
          ],
        ),
      ],
    );
  }
}
