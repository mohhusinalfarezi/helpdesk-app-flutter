import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'submit_ticket_screen.dart';

class MyAssetsScreen extends StatefulWidget {
  const MyAssetsScreen({super.key});

  @override
  State<MyAssetsScreen> createState() => _MyAssetsScreenState();
}

class _MyAssetsScreenState extends State<MyAssetsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _assets = [];

  @override
  void initState() {
    super.initState();
    _fetchMyAssets();
  }

  Future<void> _fetchMyAssets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null || token.trim().isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Sesi login tidak valid. Silakan login kembali.';
          });
        }
        return;
      }

      final cleanToken = token.startsWith('Bearer ')
          ? token.substring(7).trim()
          : token.trim();

      final url = Uri.parse('http://10.0.2.2:8080/api/assets/my');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $cleanToken',
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
          _assets = listData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Gagal memuat daftar perangkat (Status ${response.statusCode})';
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

  IconData _getAssetIcon(String? type, String? name) {
    final t = (type ?? '').toUpperCase();
    final n = (name ?? '').toUpperCase();

    if (t.contains('LAPTOP') ||
        n.contains('LAPTOP') ||
        n.contains('MACBOOK') ||
        n.contains('THINKPAD')) {
      return Icons.laptop_mac;
    }
    if (t.contains('PC') ||
        t.contains('DESKTOP') ||
        n.contains('DESKTOP') ||
        n.contains('PC')) {
      return Icons.desktop_windows;
    }
    if (t.contains('MONITOR') ||
        t.contains('SCREEN') ||
        t.contains('TV') ||
        n.contains('MONITOR')) {
      return Icons.tv;
    }
    return Icons.devices_other;
  }

  Map<String, dynamic> _getStatusConfig(String? rawStatus) {
    final status = (rawStatus ?? 'IN_USE').toUpperCase().trim();

    switch (status) {
      case 'IN_USE':
      case 'ACTIVE':
      case 'ASSIGNED':
      case 'SEDANG DIGUNAKAN':
        return {
          'label': 'in_use'.tr(),
          'textColor': const Color(0xFF059669),
          'bgColor': const Color(0xFFECFDF5),
          'borderColor': const Color(0xFFA7F3D0),
        };
      case 'MAINTENANCE':
      case 'IN_REPAIR':
      case 'PERBAIKAN':
        return {
          'label': 'in_repair'.tr(),
          'textColor': const Color(0xFFD97706),
          'bgColor': const Color(0xFFFFFBEB),
          'borderColor': const Color(0xFFFDE68A),
        };
      case 'AVAILABLE':
      case 'READY':
        return {
          'label': 'available'.tr(),
          'textColor': const Color(0xFF2563EB),
          'bgColor': const Color(0xFFEFF6FF),
          'borderColor': const Color(0xFFBFDBFE),
        };
      case 'RETURNED':
      case 'DECOMMISSIONED':
        return {
          'label': 'Non-Aktif',
          'textColor': const Color(0xFF6B7280),
          'bgColor': const Color(0xFFF3F4F6),
          'borderColor': const Color(0xFFE5E7EB),
        };
      default:
        return {
          'label': status.replaceAll('_', ' '),
          'textColor': const Color(0xFF059669),
          'bgColor': const Color(0xFFECFDF5),
          'borderColor': const Color(0xFFA7F3D0),
        };
    }
  }

  void _reportIssueForAsset(Map<String, dynamic> asset) {
    final assetName = asset['name'] ??
        asset['assetName'] ??
        asset['deviceName'] ??
        'Perangkat';
    final assetTag = asset['assetTag'] ??
        asset['tag'] ??
        asset['assetCode'] ??
        asset['code'] ??
        '-';
    final assetType = asset['type'] ?? asset['assetType'] ?? '';
    final specs = asset['specifications'] ??
        asset['specs'] ??
        asset['description'] ??
        '-';
    final serialNo = asset['serialNumber'] ?? asset['serial_number'] ?? '';

    final initialDescription = 'Kendala pada perangkat:\n'
        '• Nama Perangkat: $assetName\n'
        '• Tag Aset: $assetTag'
        '${assetType.toString().isNotEmpty ? '\n• Tipe: $assetType' : ''}'
        '${serialNo.toString().isNotEmpty ? '\n• Serial Number: $serialNo' : ''}'
        '\n• Spesifikasi: $specs\n\n'
        'Deskripsi Kendala/Kerusakan: ';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubmitTicketScreen(
          initialDescription: initialDescription,
          initialCategoryId: '1', // Hardware
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
          'my_devices_title'.tr(),
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF1E293B),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF48CEA4),
        onRefresh: _fetchMyAssets,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF48CEA4),
        ),
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
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
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
                onPressed: _fetchMyAssets,
                icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                label: Text(
                  'try_again'.tr(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF48CEA4),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

    if (_assets.isEmpty) {
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
                  Icons.devices_other_outlined,
                  size: 46,
                  color: Color(0xFF48CEA4),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'no_devices_title'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'no_devices_desc'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _fetchMyAssets,
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: _assets.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final item = _assets[index];
        if (item is! Map<String, dynamic>) {
          return const SizedBox.shrink();
        }
        return _buildAssetCard(item);
      },
    );
  }

  Widget _buildAssetCard(Map<String, dynamic> asset) {
    final assetName = asset['name'] ??
        asset['assetName'] ??
        asset['deviceName'] ??
        'Perangkat';
    final assetTag = asset['assetTag'] ??
        asset['tag'] ??
        asset['assetCode'] ??
        asset['code'] ??
        'N/A';
    final assetType = asset['type'] ?? asset['assetType'] ?? '';
    final specs = asset['specifications'] ??
        asset['specs'] ??
        asset['description'] ??
        '';
    final rawStatus = asset['status']?.toString();
    final serialNo = asset['serialNumber'] ?? asset['serial_number'] ?? '';

    final statusConfig = _getStatusConfig(rawStatus);
    final iconData = _getAssetIcon(assetType.toString(), assetName.toString());

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF48CEA4).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    iconData,
                    color: const Color(0xFF48CEA4),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assetName.toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          assetTag.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusConfig['bgColor'] as Color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusConfig['borderColor'] as Color,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusConfig['textColor'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusConfig['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusConfig['textColor'] as Color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (specs.toString().trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.tune,
                      size: 15,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        specs.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (serialNo.toString().trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  'S/N: $serialNo',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _reportIssueForAsset(asset),
                  icon: const Icon(
                    Icons.report_problem_outlined,
                    size: 16,
                    color: Color(0xFFEF4444),
                  ),
                  label: Text(
                    'report_issue'.tr(),
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
