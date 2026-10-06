import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

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

  // Pesan bawaan saat pertama kali dibuka
  final List<Map<String, dynamic>> messages = [
    {
      'text': 'Halo! Saya Hazel, asisten AI Helpdesk Anda. Ada yang bisa saya bantu hari ini?',
      'isUser': false,
      'time': 'Sekarang',
      'imagePath': null,
    },
  ];

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

  // 3. Fungsi Utama Mengirim Pesan (Teks + Gambar)
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
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8080/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': text,
          'ticketId': '', // Kosongkan sementara
          'imageUrl': imageUrl, // Kirim URL gambar jika ada
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final botReply = responseData['reply'] ?? 'Maaf, terjadi kesalahan.';
        setState(() {
          messages.add({
            'text': botReply,
            'isUser': false,
            'time': TimeOfDay.now().format(context),
            'imagePath': null,
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
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
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
              itemCount: messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                // Typing indicator as the last item
                if (_isTyping && index == messages.length) {
                  return _buildTypingIndicator();
                }
                final message = messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
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
                        Text(
                          message['text'],
                          style: TextStyle(
                            color: isUser ? Colors.white : navySlate,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
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
            child: const Text(
              "Hazel is typing...",
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: greyText,
                fontSize: 14,
              ),
            ),
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
                  onPressed: _pickImage,
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
                  onTap: _sendMessage,
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
