import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:helpdesk_app/config/api_config.dart';
import 'submit_ticket_screen.dart';

class ServiceCatalogScreen extends StatefulWidget {
  const ServiceCatalogScreen({super.key});

  @override
  State<ServiceCatalogScreen> createState() => _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends State<ServiceCatalogScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _catalogs = [];

  @override
  void initState() {
    super.initState();
    _fetchCatalogs();
  }

  Future<void> _fetchCatalogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      final cleanToken = token.startsWith('Bearer ')
          ? token.substring(7).trim()
          : token.trim();

      final url = Uri.parse('${ApiConfig.baseUrl}/api/service-catalogs');
      final response = await http.get(
        url,
        headers: {
          if (cleanToken.isNotEmpty) 'Authorization': 'Bearer $cleanToken',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> listData = [];

        if (decoded is List) {
          listData = decoded;
        } else if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is List) {
            listData = decoded['data'];
          } else if (decoded['content'] is List) {
            listData = decoded['content'];
          }
        }

        setState(() {
          _catalogs = listData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Gagal memuat katalog layanan (HTTP ${response.statusCode})';
          _isLoading = false;
        });
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

  IconData _getIconFromCode(String? code, String? title) {
    final c = (code ?? '').toLowerCase().trim();
    final t = (title ?? '').toLowerCase().trim();

    if (c.contains('code') ||
        c.contains('dev') ||
        t.contains('aplikasi') ||
        t.contains('software') ||
        t.contains('source code')) {
      return Icons.code_rounded;
    }
    if (c.contains('vpn') ||
        c.contains('network') ||
        c.contains('jaringan') ||
        t.contains('vpn') ||
        t.contains('wifi') ||
        t.contains('internet')) {
      return Icons.vpn_lock_rounded;
    }
    if (c.contains('memory') ||
        c.contains('ram') ||
        c.contains('hardware') ||
        t.contains('upgrade') ||
        t.contains('ram') ||
        t.contains('hardware') ||
        t.contains('ssd')) {
      return Icons.memory_rounded;
    }
    if (c.contains('mail') ||
        c.contains('email') ||
        t.contains('email') ||
        t.contains('mailbox')) {
      return Icons.mark_email_read_rounded;
    }
    if (c.contains('mouse') ||
        c.contains('peripheral') ||
        t.contains('mouse') ||
        t.contains('keyboard') ||
        t.contains('periferal')) {
      return Icons.mouse_rounded;
    }
    if (c.contains('design') ||
        c.contains('ui') ||
        t.contains('desain') ||
        t.contains('grafis') ||
        t.contains('creative')) {
      return Icons.design_services_rounded;
    }
    return Icons.layers_outlined;
  }

  String _mapToCategoryId(String? category) {
    final cat = (category ?? '').toLowerCase();
    if (cat.contains('hard') ||
        cat.contains('perangkat keras') ||
        cat.contains('device') ||
        cat.contains('ram') ||
        cat.contains('periferal')) {
      return '1'; // Hardware
    }
    if (cat.contains('soft') ||
        cat.contains('aplikasi') ||
        cat.contains('app') ||
        cat.contains('lisensi') ||
        cat.contains('coding')) {
      return '2'; // Software
    }
    if (cat.contains('net') ||
        cat.contains('jaringan') ||
        cat.contains('vpn') ||
        cat.contains('wifi') ||
        cat.contains('internet')) {
      return '3'; // Network
    }
    return '4'; // General IT
  }

  Color _getCategoryColor(String? category) {
    final cat = (category ?? '').toLowerCase();
    if (cat.contains('soft') || cat.contains('app')) {
      return const Color(0xFF3B82F6);
    }
    if (cat.contains('hard') || cat.contains('device')) {
      return const Color(0xFFF59E0B);
    }
    if (cat.contains('net') || cat.contains('vpn')) {
      return const Color(0xFF10B981);
    }
    return const Color(0xFF8B5CF6);
  }

  void _onRequestService(Map<String, dynamic> item) {
    final title = (item['title'] ?? item['name'] ?? 'Layanan IT').toString();
    final category = item['category']?.toString();
    final categoryId = _mapToCategoryId(category);
    final draftText = '[Permintaan Layanan: $title]\n\nDetail kebutuhan: ';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubmitTicketScreen(
          initialDescription: draftText,
          initialCategoryId: categoryId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'service_catalog_title'.tr(),
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
            icon: const Icon(Icons.refresh, color: Color(0xFF48CEA4)),
            tooltip: 'refresh_data'.tr(),
            onPressed: _fetchCatalogs,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF48CEA4),
        onRefresh: _fetchCatalogs,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF48CEA4)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Color(0xFFEF4444),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'error_occurred'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchCatalogs,
                icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                label: Text(
                  'try_again'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF48CEA4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_catalogs.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF48CEA4).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.layers_clear_outlined,
                  size: 46,
                  color: Color(0xFF48CEA4),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'no_catalogs_title'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'no_catalogs_desc'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _fetchCatalogs,
                icon: const Icon(Icons.refresh, color: Color(0xFF48CEA4), size: 18),
                label: Text(
                  'reload'.tr(),
                  style: const TextStyle(
                    color: Color(0xFF48CEA4),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF48CEA4)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _catalogs.length,
      itemBuilder: (context, index) {
        final item = _catalogs[index];
        if (item is! Map<String, dynamic>) {
          return const SizedBox.shrink();
        }
        return _buildCatalogCard(item);
      },
    );
  }

  Widget _buildCatalogCard(Map<String, dynamic> item) {
    final title = (item['title'] ?? item['name'] ?? 'Layanan IT').toString();
    final category = (item['category'] ?? 'Umum').toString();
    final description =
        (item['description'] ?? 'Tidak ada deskripsi layanan.').toString();
    final slaEstimate = (item['slaEstimate'] ??
            item['sla'] ??
            item['estimate'] ??
            '1x24 Jam')
        .toString();
    final iconCode = item['iconCode']?.toString();

    final IconData iconData = _getIconFromCode(iconCode, title);
    final Color catColor = _getCategoryColor(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header baris ikon, judul, kategori
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Box
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF48CEA4).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    iconData,
                    color: const Color(0xFF48CEA4),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                // Judul & Badge Kategori
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: catColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // SLA Estimate Chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  slaEstimate,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Deskripsi layanan
            Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            // Tombol Ajukan Permintaan
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _onRequestService(item),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text(
                  'request_service'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF48CEA4),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
