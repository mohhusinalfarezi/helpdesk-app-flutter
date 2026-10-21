import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ManageAssetsScreen extends StatefulWidget {
  const ManageAssetsScreen({super.key});

  @override
  State<ManageAssetsScreen> createState() => _ManageAssetsScreenState();
}

class _ManageAssetsScreenState extends State<ManageAssetsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _assets = [];
  String _searchQuery = '';
  String _selectedTypeFilter = 'ALL';

  final List<String> _typeOptions = ['LAPTOP', 'PC', 'MONITOR', 'PRINTER'];

  @override
  void initState() {
    super.initState();
    _fetchAssets();
  }

  Future<void> _fetchAssets() async {
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

      final url = Uri.parse('http://10.0.2.2:8080/api/assets');
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
              'Gagal memuat daftar aset (Status ${response.statusCode})';
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

  List<dynamic> get _filteredAssets {
    return _assets.where((item) {
      if (item is! Map<String, dynamic>) return false;
      final name = (item['name'] ?? item['assetName'] ?? '').toString().toLowerCase();
      final tag = (item['assetTag'] ?? item['tag'] ?? '').toString().toLowerCase();
      final type = (item['type'] ?? item['assetType'] ?? '').toString().toUpperCase();
      final email = _getAssigneeEmail(item).toLowerCase();

      final matchesQuery = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          tag.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase());

      final matchesType =
          _selectedTypeFilter == 'ALL' || type == _selectedTypeFilter;

      return matchesQuery && matchesType;
    }).toList();
  }

  String _getAssigneeEmail(Map<String, dynamic> asset) {
    if (asset['assignedUserEmail'] != null &&
        asset['assignedUserEmail'].toString().trim().isNotEmpty) {
      return asset['assignedUserEmail'].toString().trim();
    }
    if (asset['userEmail'] != null &&
        asset['userEmail'].toString().trim().isNotEmpty) {
      return asset['userEmail'].toString().trim();
    }
    if (asset['assignedToEmail'] != null &&
        asset['assignedToEmail'].toString().trim().isNotEmpty) {
      return asset['assignedToEmail'].toString().trim();
    }
    if (asset['user'] is Map && asset['user']['email'] != null) {
      return asset['user']['email'].toString().trim();
    }
    if (asset['assignedUser'] is Map && asset['assignedUser']['email'] != null) {
      return asset['assignedUser']['email'].toString().trim();
    }
    return '';
  }

  IconData _getAssetIcon(String? type, String? name) {
    final t = (type ?? '').toUpperCase();
    final n = (name ?? '').toUpperCase();

    if (t.contains('PRINTER') || n.contains('PRINTER')) {
      return Icons.print_outlined;
    }
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
    final status = (rawStatus ?? 'AVAILABLE').toUpperCase().trim();

    switch (status) {
      case 'IN_USE':
      case 'ACTIVE':
      case 'ASSIGNED':
      case 'SEDANG DIGUNAKAN':
        return {
          'label': 'Sedang Digunakan',
          'textColor': const Color(0xFF059669),
          'bgColor': const Color(0xFFECFDF5),
          'borderColor': const Color(0xFFA7F3D0),
        };
      case 'AVAILABLE':
      case 'READY':
      case 'TERSEDIA':
        return {
          'label': 'Tersedia',
          'textColor': const Color(0xFF2563EB),
          'bgColor': const Color(0xFFEFF6FF),
          'borderColor': const Color(0xFFBFDBFE),
        };
      case 'MAINTENANCE':
      case 'IN_REPAIR':
      case 'PERBAIKAN':
        return {
          'label': 'Dalam Perbaikan',
          'textColor': const Color(0xFFD97706),
          'bgColor': const Color(0xFFFFFBEB),
          'borderColor': const Color(0xFFFDE68A),
        };
      case 'RETURNED':
      case 'DECOMMISSIONED':
      case 'BROKEN':
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

  void _showAddAssetDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final tagController = TextEditingController();
    final specsController = TextEditingController();
    final emailController = TextEditingController();
    String selectedType = _typeOptions.first;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF48CEA4).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_to_photos_outlined,
                                color: Color(0xFF48CEA4),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Tambah Perangkat Baru',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Nama Perangkat
                        const Text(
                          'Nama Perangkat *',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: 'Misal: Laptop Dell Latitude 5420',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF48CEA4),
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Nama perangkat wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Tag Aset
                        const Text(
                          'Tag Aset *',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: tagController,
                          decoration: InputDecoration(
                            hintText: 'Misal: AST-2026-099',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF48CEA4),
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Tag aset wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Tipe Perangkat Dropdown
                        const Text(
                          'Tipe Perangkat *',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          items: _typeOptions.map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Row(
                                children: [
                                  Icon(_getAssetIcon(t, null),
                                      size: 18, color: const Color(0xFF48CEA4)),
                                  const SizedBox(width: 8),
                                  Text(t),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedType = val;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Spesifikasi
                        const Text(
                          'Spesifikasi',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: specsController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Misal: Core i7 11th Gen, 16GB RAM, 512GB SSD',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF48CEA4),
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Email Pemegang
                        const Text(
                          'Email Pemegang (Karyawan)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Misal: budi@perusahaan.com (opsional jika belum ditugaskan)',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF48CEA4),
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Tombol Simpan
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (!(formKey.currentState?.validate() ?? false)) {
                                      return;
                                    }

                                    final scaffoldMessenger =
                                        ScaffoldMessenger.of(context);
                                    final navigator = Navigator.of(modalContext);

                                    setModalState(() {
                                      isSubmitting = true;
                                    });

                                    try {
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      final token = prefs.getString('jwt_token');

                                      if (token == null || token.trim().isEmpty) {
                                        scaffoldMessenger.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Sesi login tidak valid. Silakan login kembali.',
                                            ),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                        return;
                                      }

                                      final cleanToken = token.startsWith('Bearer ')
                                          ? token.substring(7).trim()
                                          : token.trim();

                                      final assignedEmail =
                                          emailController.text.trim();

                                      final bodyMap = <String, dynamic>{
                                        'name': nameController.text.trim(),
                                        'assetTag': tagController.text.trim(),
                                        'type': selectedType,
                                        'specifications':
                                            specsController.text.trim(),
                                        if (assignedEmail.isNotEmpty) ...{
                                          'assignedUserEmail': assignedEmail,
                                          'userEmail': assignedEmail,
                                        },
                                      };

                                      final url = Uri.parse(
                                        'http://10.0.2.2:8080/api/assets',
                                      );
                                      final response = await http.post(
                                        url,
                                        headers: {
                                          'Authorization': 'Bearer $cleanToken',
                                          'Content-Type': 'application/json',
                                        },
                                        body: jsonEncode(bodyMap),
                                      );

                                      if (!mounted) return;

                                      if (response.statusCode == 200 ||
                                          response.statusCode == 201) {
                                        navigator.pop();
                                        scaffoldMessenger.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Perangkat berhasil ditambahkan!',
                                            ),
                                            backgroundColor: Color(0xFF48CEA4),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                        _fetchAssets();
                                      } else {
                                        String err =
                                            'Gagal menambahkan perangkat (${response.statusCode})';
                                        try {
                                          final decoded =
                                              jsonDecode(response.body);
                                          if (decoded is Map &&
                                              decoded['message'] != null) {
                                            err = decoded['message'].toString();
                                          } else if (decoded is Map &&
                                              decoded['error'] != null) {
                                            err = decoded['error'].toString();
                                          }
                                        } catch (_) {}

                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(
                                            content: Text(err),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Kesalahan jaringan: $e',
                                            ),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                    } finally {
                                      setModalState(() {
                                        isSubmitting = false;
                                      });
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF48CEA4),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Simpan Perangkat',
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
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAssets;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'manage_assets_title'.tr(),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF48CEA4)),
            tooltip: 'refresh_data'.tr(),
            onPressed: _fetchAssets,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAssetDialog,
        backgroundColor: const Color(0xFF48CEA4),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'add_device'.tr(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF48CEA4),
        onRefresh: _fetchAssets,
        child: Column(
          children: [
            _buildSearchAndFilters(),
            Expanded(
              child: _buildBody(filtered),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          // Search Field
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              decoration: const InputDecoration(
                hintText: 'Cari perangkat, tag, atau email...',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Horizontal Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('ALL', 'Semua'),
                const SizedBox(width: 8),
                _buildFilterChip('LAPTOP', 'Laptop'),
                const SizedBox(width: 8),
                _buildFilterChip('PC', 'PC / Desktop'),
                const SizedBox(width: 8),
                _buildFilterChip('MONITOR', 'Monitor'),
                const SizedBox(width: 8),
                _buildFilterChip('PRINTER', 'Printer'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedTypeFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTypeFilter = key;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF48CEA4)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<dynamic> items) {
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
                onPressed: _fetchAssets,
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

    if (items.isEmpty) {
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
                  Icons.inventory_2_outlined,
                  size: 46,
                  color: Color(0xFF48CEA4),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tidak Ada Aset',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty || _selectedTypeFilter != 'ALL'
                    ? 'Tidak ada perangkat yang cocok dengan kriteria pencarian.'
                    : 'Belum ada aset terdaftar di sistem. Tekan tombol (+) di bawah untuk menambahkan.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _showAddAssetDialog,
                icon: const Icon(Icons.add, color: Color(0xFF48CEA4), size: 18),
                label: const Text(
                  'Tambah Sekarang',
                  style: TextStyle(
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
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
        '-';
    final assetType = (asset['type'] ?? asset['assetType'] ?? '').toString();
    final specs = (asset['specifications'] ??
            asset['specs'] ??
            asset['description'] ??
            '')
        .toString();
    final rawStatus = asset['status']?.toString();
    final assigneeEmail = _getAssigneeEmail(asset);

    final statusConfig = _getStatusConfig(rawStatus);
    final iconData = _getAssetIcon(assetType, assetName.toString());

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
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF48CEA4).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    iconData,
                    color: const Color(0xFF48CEA4),
                    size: 24,
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
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
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          if (assetType.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                assetType,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0369A1),
                                ),
                              ),
                            ),
                          ],
                        ],
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
                  child: Text(
                    statusConfig['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusConfig['textColor'] as Color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Email Pemegang
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Text(
                  'Pemegang: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                Expanded(
                  child: Text(
                    assigneeEmail.isNotEmpty ? assigneeEmail : 'Belum Ditugaskan',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: assigneeEmail.isNotEmpty
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: assigneeEmail.isNotEmpty
                          ? const Color(0xFF1E293B)
                          : const Color(0xFF94A3B8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            if (specs.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.tune,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      specs,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
