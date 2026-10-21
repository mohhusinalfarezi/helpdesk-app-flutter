import 'dart:convert';
import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class KnowledgeArticle {
  final String id;
  final String title;
  final String category;
  final String readingTime;
  final String summary;
  final List<String> steps;
  final String tip;

  const KnowledgeArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.readingTime,
    required this.summary,
    required this.steps,
    required this.tip,
  });

  factory KnowledgeArticle.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ??
        json['articleId']?.toString() ??
        '';
    final rawTitle = json['title']?.toString() ??
        json['judul']?.toString() ??
        'Panduan Solusi';
    final rawCategory = json['category']?.toString() ??
        json['kategori']?.toString() ??
        'Software';
    final rawContent = json['content']?.toString() ??
        json['solution']?.toString() ??
        json['isi']?.toString() ??
        json['description']?.toString() ??
        '';
    final rawSummary = json['summary']?.toString() ??
        (rawContent.length > 110
            ? '${rawContent.substring(0, 110)}...'
            : rawContent);
    final rawTip = json['tip']?.toString() ?? json['catatan']?.toString() ?? '';

    // Hitung estimasi waktu baca
    final int estimatedMinutes = (rawContent.length / 250).clamp(1, 10).toInt();
    final rawReadingTime = json['readingTime']?.toString() ??
        '$estimatedMinutes mnt baca';

    // Parse list of steps jika dikembalikan sebagai list atau baris baru
    List<String> parsedSteps = [];
    final dynamic stepsField = json['steps'];
    if (stepsField is List && stepsField.isNotEmpty) {
      parsedSteps = stepsField.map((s) => s.toString()).toList();
    } else if (rawContent.trim().isNotEmpty) {
      final lines = rawContent
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      parsedSteps = lines.isNotEmpty ? lines : [rawContent];
    }

    return KnowledgeArticle(
      id: rawId,
      title: rawTitle,
      category: rawCategory,
      readingTime: rawReadingTime,
      summary: rawSummary,
      steps: parsedSteps,
      tip: rawTip,
    );
  }

  IconData get icon {
    switch (category.toLowerCase()) {
      case 'jaringan':
        return Icons.wifi_tethering_rounded;
      case 'hardware':
        return Icons.devices_rounded;
      case 'software':
      default:
        return Icons.integration_instructions_rounded;
    }
  }
}

class KnowledgeBaseScreen extends StatefulWidget {
  const KnowledgeBaseScreen({super.key});

  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Semua';
  String _searchQuery = '';

  bool _isLoading = true;
  String _errorMessage = '';
  List<KnowledgeArticle> _articles = [];
  String _userRole = 'USER';
  String? _jwtToken;

  final List<String> _categories = [
    'Semua',
    'Jaringan',
    'Hardware',
    'Software',
  ];

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

  bool get _isStaff => _userRole == 'ADMIN' || _userRole == 'TECHNICIAN';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await _loadUserSession();
    await _fetchArticles();
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

  Future<void> _fetchArticles() async {
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
        Uri.parse('$_baseUrl/knowledge-articles'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final List<dynamic> listData =
            decoded is List ? decoded : (decoded['content'] ?? []);

        final items = listData
            .map((item) =>
                KnowledgeArticle.fromJson(item as Map<String, dynamic>))
            .toList();

        if (mounted) {
          setState(() {
            _articles = items;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Gagal memuat artikel panduan (Status: ${response.statusCode})';
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

  List<KnowledgeArticle> get _filteredArticles {
    return _articles.where((article) {
      final matchesCategory = _selectedCategory == 'Semua' ||
          article.category.toLowerCase() == _selectedCategory.toLowerCase();

      final query = _searchQuery.toLowerCase().trim();
      if (query.isEmpty) {
        return matchesCategory;
      }

      final matchesQuery = article.title.toLowerCase().contains(query) ||
          article.category.toLowerCase().contains(query) ||
          article.summary.toLowerCase().contains(query) ||
          article.steps.any((s) => s.toLowerCase().contains(query));

      return matchesCategory && matchesQuery;
    }).toList();
  }

  Future<void> _confirmDeleteArticle(
    KnowledgeArticle item, {
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
              'Hapus Artikel',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus artikel panduan "${item.title}"?\n\nTindakan ini tidak dapat dibatalkan.',
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
      await _deleteArticle(item.id, onSuccess: onSuccess);
    }
  }

  Future<void> _deleteArticle(
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
        Uri.parse('$_baseUrl/knowledge-articles/$id'),
        headers: headers,
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Artikel berhasil dihapus'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(0xFF1E293B),
            ),
          );
        }
        onSuccess?.call();
        _fetchArticles();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gagal menghapus artikel (Status: ${response.statusCode})',
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

  void _showCreateArticleModal() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final solutionController = TextEditingController();
    String selectedCategory = 'Jaringan';
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
                              Icons.menu_book_rounded,
                              color: Color(0xFF48CEA4),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tambah Artikel Baru',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                'Panduan mandiri pemecahan masalah IT',
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

                      // Field Judul Artikel
                      const Text(
                        'Judul Artikel',
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
                          hintText: 'Contoh: Panduan Mengatasi Wi-Fi Tidak Terdeteksi',
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
                            return 'Judul artikel wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Dropdown Kategori
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
                            horizontal: 14,
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
                            value: 'Jaringan',
                            child: Text('Jaringan'),
                          ),
                          DropdownMenuItem(
                            value: 'Hardware',
                            child: Text('Hardware'),
                          ),
                          DropdownMenuItem(
                            value: 'Software',
                            child: Text('Software'),
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
                      const SizedBox(height: 16),

                      // Field Isi Panduan / Solusi
                      const Text(
                        'Isi Panduan / Solusi',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: solutionController,
                        maxLines: 6,
                        minLines: 4,
                        decoration: InputDecoration(
                          hintText:
                              'Tuliskan langkah-langkah solusi secara berurutan...\nContoh:\n1. Restart perangkat router\n2. Periksa kabel LAN\n3. Flush DNS pada laptop',
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
                            return 'Isi panduan / solusi wajib diisi';
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
                                  final solution =
                                      solutionController.text.trim();
                                  final summary = solution.length > 110
                                      ? '${solution.substring(0, 110)}...'
                                      : solution;

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
                                      'content': solution,
                                      'solution': solution,
                                      'description': solution,
                                      'summary': summary,
                                    });

                                    final response = await http.post(
                                      Uri.parse('$_baseUrl/knowledge-articles'),
                                      headers: headers,
                                      body: body,
                                    );

                                    if (response.statusCode == 200 ||
                                        response.statusCode == 201) {
                                      navigator.pop();
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Artikel panduan berhasil disimpan!',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: Color(0xFF48CEA4),
                                        ),
                                      );
                                      if (mounted) {
                                        _fetchArticles();
                                      }
                                    } else {
                                      setModalState(() {
                                        isSubmitting = false;
                                      });
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Gagal menyimpan artikel (${response.statusCode})',
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
                                  'Simpan Artikel',
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

  void _showArticleDetail(BuildContext context, KnowledgeArticle article) {
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

                  // Category & Reading time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF48CEA4).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          article.category,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F9B73),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            article.readingTime,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Title
                  Text(
                    article.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Summary
                  Text(
                    article.summary,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 18),

                  // Step by Step Section Header
                  const Text(
                    'Langkah-Langkah Solusi:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Steps List
                  ...List.generate(article.steps.length, (idx) {
                    final stepText = article.steps[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: Color(0xFF48CEA4),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              stepText,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF334155),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  if (article.tip.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    // Pro Tip Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline,
                            color: Color(0xFFD97706),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              article.tip,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF92400E),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      if (_isStaff && article.id.isNotEmpty) ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmDeleteArticle(article);
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
                            'Selesai Membaca',
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
    final filtered = _filteredArticles;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'knowledge_base_title'.tr(),
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
            onPressed: _fetchArticles,
          ),
        ],
      ),
      floatingActionButton: _isStaff
          ? FloatingActionButton.extended(
              onPressed: _showCreateArticleModal,
              backgroundColor: const Color(0xFF48CEA4),
              foregroundColor: Colors.white,
              elevation: 4,
              tooltip: 'Tambah Artikel',
              icon: const Icon(Icons.add),
              label: const Text(
                'Tambah Artikel',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: RefreshIndicator(
        color: const Color(0xFF48CEA4),
        onRefresh: _fetchArticles,
        child: Column(
          children: [
            // Search & Filter Header Container
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Cari panduan solutif (misal: Wi-Fi, printer)...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF94A3B8),
                        size: 22,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.cancel,
                                color: Color(0xFF94A3B8),
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Horizontal Category Chips
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = _selectedCategory == category;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF48CEA4)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                category,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Article List Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF48CEA4),
                      ),
                    )
                  : _errorMessage.isNotEmpty && _articles.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(32),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.2,
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
                                    onPressed: _fetchArticles,
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text('Coba Lagi'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF48CEA4),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : filtered.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(32.0),
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.2,
                                ),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF1F5F9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.search_off_rounded,
                                          size: 48,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Tidak Ada Artikel Ditemukan',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Coba gunakan kata kunci pencarian yang lain atau ganti filter kategori.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      if (_isStaff) ...[
                                        const SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          onPressed: _showCreateArticleModal,
                                          icon: const Icon(Icons.add, size: 18),
                                          label: const Text('Tambah Artikel Baru'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF48CEA4),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
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
                              padding:
                                  const EdgeInsets.fromLTRB(20, 20, 20, 90),
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final article = filtered[index];
                                return InkWell(
                                  onTap: () =>
                                      _showArticleDetail(context, article),
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
                                          color: Colors.black
                                              .withValues(alpha: 0.03),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Top Header: Category Tag & Icon & Delete (if staff)
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF48CEA4)
                                                    .withValues(alpha: 0.12),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                article.icon,
                                                size: 18,
                                                color: const Color(0xFF48CEA4),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                article.category,
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
                                                  Icons.schedule,
                                                  size: 12,
                                                  color: Color(0xFF94A3B8),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  article.readingTime,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF94A3B8),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (_isStaff &&
                                                article.id.isNotEmpty) ...[
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  size: 18,
                                                  color: Color(0xFFDC2626),
                                                ),
                                                tooltip: 'Hapus Artikel',
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                onPressed: () =>
                                                    _confirmDeleteArticle(
                                                        article),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Title
                                        Text(
                                          article.title,
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
                                          article.summary,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF64748B),
                                            height: 1.4,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 12),

                                        // Footer CTA
                                        const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Baca Panduan',
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
          ],
        ),
      ),
    );
  }
}
