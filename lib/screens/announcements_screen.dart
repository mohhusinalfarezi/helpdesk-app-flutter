import 'dart:convert';
import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AnnouncementData {
  final String id;
  final String title;
  final String category;
  final String priority;
  final String date;
  final String summary;
  final String fullContent;

  const AnnouncementData({
    required this.id,
    required this.title,
    required this.category,
    required this.priority,
    required this.date,
    required this.summary,
    required this.fullContent,
  });

  factory AnnouncementData.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ??
        json['announcementId']?.toString() ??
        '';
    final rawTitle = json['title']?.toString() ??
        json['judul']?.toString() ??
        'Pengumuman';
    final rawCategory = json['category']?.toString() ??
        json['kategori']?.toString() ??
        'Info';
    final rawPriority = json['priority']?.toString() ??
        json['tag']?.toString() ??
        json['priorityLevel']?.toString() ??
        'INFO';
    final rawContent = json['content']?.toString() ??
        json['fullContent']?.toString() ??
        json['isi']?.toString() ??
        json['description']?.toString() ??
        '';
    final rawSummary = json['summary']?.toString() ??
        (rawContent.length > 110
            ? '${rawContent.substring(0, 110)}...'
            : rawContent);
    final rawDate = json['createdAt']?.toString() ??
        json['createdDate']?.toString() ??
        json['date']?.toString() ??
        '';

    return AnnouncementData(
      id: rawId,
      title: rawTitle,
      category: rawCategory,
      priority: rawPriority.toUpperCase(),
      date: _formatDate(rawDate),
      summary: rawSummary,
      fullContent: rawContent,
    );
  }

  static String _formatDate(String rawDate) {
    if (rawDate.trim().isEmpty) return 'Hari ini';
    try {
      final dt = DateTime.parse(rawDate);
      const months = [
        '',
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];
      final monthName = (dt.month >= 1 && dt.month <= 12)
          ? months[dt.month]
          : '${dt.month}';
      return '${dt.day} $monthName ${dt.year}';
    } catch (_) {
      return rawDate;
    }
  }

  IconData get icon {
    switch (category.toLowerCase()) {
      case 'maintenance':
        return Icons.build_circle_outlined;
      case 'kebijakan':
        return Icons.security_outlined;
      case 'sistem':
        return Icons.auto_awesome_outlined;
      case 'info':
      default:
        return Icons.campaign_outlined;
    }
  }

  Color get badgeColor {
    switch (priority.toUpperCase()) {
      case 'PENTING':
        return const Color(0xFFFEF3C7);
      case 'WAJIB':
        return const Color(0xFFFEE2E2);
      case 'PEMBARUAN':
        return const Color(0xFFDCFCE7);
      case 'INFO':
      default:
        return const Color(0xFFE0F2FE);
    }
  }

  Color get badgeTextColor {
    switch (priority.toUpperCase()) {
      case 'PENTING':
        return const Color(0xFFD97706);
      case 'WAJIB':
        return const Color(0xFFDC2626);
      case 'PEMBARUAN':
        return const Color(0xFF16A34A);
      case 'INFO':
      default:
        return const Color(0xFF0284C7);
    }
  }
}

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<AnnouncementData> _announcements = [];
  String _userRole = 'USER';
  String? _jwtToken;

  String get _baseUrl {
    if (kIsWeb) return 'http://localhost:8080/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8080/api';
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        return 'http://localhost:8080/api';
      }
    } catch (_) {}
    return 'http://10.0.2.2:8080/api';
  }

  bool get _isStaff =>
      _userRole == 'ADMIN' || _userRole == 'TECHNICIAN';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _loadUserSession();
    await _fetchAnnouncements();
  }

  String _extractRoleFromJwt(String? token) {
    if (token == null || token.isEmpty) return 'USER';
    try {
      final parts = token.split('.');
      if (parts.length >= 2) {
        final payloadPart = parts[1];
        final normalized = base64Url.normalize(payloadPart);
        final decodedBytes = base64Url.decode(normalized);
        final decodedString = utf8.decode(decodedBytes);
        final Map<String, dynamic> payloadMap = jsonDecode(decodedString);

        dynamic rawRole = payloadMap['role'] ??
            payloadMap['roles'] ??
            payloadMap['authorities'] ??
            payloadMap['roleName'];

        if (rawRole is List && rawRole.isNotEmpty) {
          rawRole = rawRole.first;
        }

        if (rawRole != null) {
          String roleStr = rawRole.toString().trim().toUpperCase();
          if (roleStr.startsWith('ROLE_')) {
            roleStr = roleStr.substring(5);
          }
          return roleStr;
        }
      }
    } catch (e) {
      debugPrint('Error decoding role from JWT: $e');
    }
    return 'USER';
  }

  Future<void> _loadUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    String role = prefs.getString('user_role') ?? '';

    if (role.isEmpty || role == 'USER') {
      final jwtRole = _extractRoleFromJwt(token);
      if (jwtRole != 'USER') {
        role = jwtRole;
      }
    }

    if (mounted) {
      setState(() {
        _jwtToken = token;
        _userRole = role.toUpperCase();
      });
    }
  }

  Future<void> _fetchAnnouncements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? _jwtToken ?? '';

      final headers = {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('$_baseUrl/announcements'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final List<dynamic> listData =
            decoded is List ? decoded : (decoded['content'] ?? []);

        final items = listData
            .map((item) =>
                AnnouncementData.fromJson(item as Map<String, dynamic>))
            .toList();

        if (mounted) {
          setState(() {
            _announcements = items;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Gagal memuat pengumuman (Status: ${response.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Tidak dapat terhubung ke server: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteAnnouncement(
    AnnouncementData item, {
    VoidCallback? onSuccess,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text(
              'Hapus Pengumuman',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus pengumuman "${item.title}"?\n\nTindakan ini tidak dapat dibatalkan.',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF475569),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteAnnouncement(item.id, onSuccess: onSuccess);
    }
  }

  Future<void> _deleteAnnouncement(
    String id, {
    VoidCallback? onSuccess,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? _jwtToken ?? '';

      final headers = {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.delete(
        Uri.parse('$_baseUrl/announcements/$id'),
        headers: headers,
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pengumuman berhasil dihapus'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(0xFF1E293B),
            ),
          );
        }
        onSuccess?.call();
        _fetchAnnouncements();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gagal menghapus pengumuman (Status: ${response.statusCode})',
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _showCreateAnnouncementModal() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String selectedCategory = 'Maintenance';
    String selectedPriority = 'PENTING';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (sbContext, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                14,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Grab handle
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF48CEA4)
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.campaign_rounded,
                              color: Color(0xFF48CEA4),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tambah Pengumuman',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                'Publikasikan informasi resmi untuk pengguna',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Field Judul
                      const Text(
                        'Judul Pengumuman',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: 'Contoh: Pemeliharaan Jaringan Gedung B',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Judul wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Dropdown Kategori & Dropdown Prioritas
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Kategori',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedCategory,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Maintenance',
                                      child: Text('Maintenance'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Kebijakan',
                                      child: Text('Kebijakan'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Info',
                                      child: Text('Info'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Sistem',
                                      child: Text('Sistem'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(() {
                                        selectedCategory = val;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tag / Prioritas',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedPriority,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'PENTING',
                                      child: Text('PENTING'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'WAJIB',
                                      child: Text('WAJIB'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'INFO',
                                      child: Text('INFO'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'PEMBARUAN',
                                      child: Text('PEMBARUAN'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(() {
                                        selectedPriority = val;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Field Isi Pengumuman
                      const Text(
                        'Isi Pengumuman',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: contentController,
                        maxLines: 5,
                        minLines: 3,
                        decoration: InputDecoration(
                          hintText:
                              'Tuliskan isi detail pengumuman, jadwal pelaksanaan, atau instruksi langkah kerja...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Isi pengumuman wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;

                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  final navigator =
                                      Navigator.of(bottomSheetContext);

                                  setModalState(() {
                                    isSubmitting = true;
                                  });

                                  final title = titleController.text.trim();
                                  final content = contentController.text.trim();
                                  final summary = content.length > 110
                                      ? '${content.substring(0, 110)}...'
                                      : content;

                                  try {
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    final token = prefs.getString('jwt_token') ??
                                        _jwtToken ??
                                        '';

                                    final headers = {
                                      'Content-Type': 'application/json',
                                      if (token.isNotEmpty)
                                        'Authorization': 'Bearer $token',
                                    };

                                    final body = jsonEncode({
                                      'title': title,
                                      'category': selectedCategory,
                                      'priority': selectedPriority,
                                      'tag': selectedPriority,
                                      'content': content,
                                      'description': content,
                                      'summary': summary,
                                    });

                                    final response = await http.post(
                                      Uri.parse('$_baseUrl/announcements'),
                                      headers: headers,
                                      body: body,
                                    );

                                    if (response.statusCode == 200 ||
                                        response.statusCode == 201) {
                                      navigator.pop();
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Pengumuman berhasil dipublikasikan!',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: Color(0xFF48CEA4),
                                        ),
                                      );
                                      if (mounted) {
                                        _fetchAnnouncements();
                                      }
                                    } else {
                                      setModalState(() {
                                        isSubmitting = false;
                                      });
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Gagal membuat pengumuman (${response.statusCode})',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor:
                                              const Color(0xFFDC2626),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setModalState(() {
                                      isSubmitting = false;
                                    });
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Terjadi error: $e'),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor:
                                            const Color(0xFFDC2626),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF48CEA4),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Publikasikan Pengumuman',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDetailBottomSheet(BuildContext context, AnnouncementData item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Grab handle
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header Badges & Date
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: item.badgeColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.priority,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: item.badgeTextColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.category,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            item.date,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 16),

                  // Full Content
                  Text(
                    item.fullContent.isNotEmpty
                        ? item.fullContent
                        : item.summary,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF334155),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Action Buttons
                  Row(
                    children: [
                      if (_isStaff && item.id.isNotEmpty) ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmDeleteAnnouncement(item);
                          },
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFDC2626),
                            size: 18,
                          ),
                          label: const Text(
                            'Hapus',
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Tutup',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'announcements_title'.tr(),
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF1E293B),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF1E293B)),
            tooltip: 'Segarkan',
            onPressed: _fetchAnnouncements,
          ),
        ],
      ),
      floatingActionButton: _isStaff
          ? FloatingActionButton.extended(
              onPressed: _showCreateAnnouncementModal,
              backgroundColor: const Color(0xFF48CEA4),
              foregroundColor: Colors.white,
              elevation: 4,
              tooltip: 'Tambah Pengumuman',
              icon: const Icon(Icons.add),
              label: const Text(
                'Tambah Pengumuman',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: RefreshIndicator(
        color: const Color(0xFF48CEA4),
        onRefresh: _fetchAnnouncements,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF48CEA4),
                ),
              )
            : _errorMessage.isNotEmpty && _announcements.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(32),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.25,
                      ),
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFEE2E2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.error_outline,
                                size: 40,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _fetchAnnouncements,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Coba Lagi'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF48CEA4),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : _announcements.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(32),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.25,
                          ),
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.campaign_outlined,
                                    size: 48,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Belum Ada Pengumuman',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Pengumuman resmi dari tim IT akan ditampilkan di sini.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                if (_isStaff) ...[
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _showCreateAnnouncementModal,
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Tambah Sekarang'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF48CEA4),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
                        itemCount: _announcements.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final item = _announcements[index];
                          return InkWell(
                            onTap: () => _showDetailBottomSheet(context, item),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0)
                                      .withValues(alpha: 0.6),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Row: Category Icon + Tag & Date + Delete (if staff)
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: item.badgeColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          item.icon,
                                          color: item.badgeTextColor,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: item.badgeColor,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.priority,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: item.badgeTextColor,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.category,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_today_outlined,
                                            size: 12,
                                            color: Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            item.date,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_isStaff && item.id.isNotEmpty) ...[
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Color(0xFFDC2626),
                                          ),
                                          tooltip: 'Hapus Pengumuman',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () =>
                                              _confirmDeleteAnnouncement(item),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Title
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Summary
                                  Text(
                                    item.summary,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),

                                  // Footer action hint
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Lihat Selengkapnya',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF48CEA4),
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 11,
                                        color: Color(0xFF48CEA4),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
