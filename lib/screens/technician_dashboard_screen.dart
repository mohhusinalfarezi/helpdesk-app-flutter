import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';
import 'ticket_detail_screen.dart';

class TechnicianDashboardScreen extends StatefulWidget {
  const TechnicianDashboardScreen({super.key});

  @override
  State<TechnicianDashboardScreen> createState() =>
      _TechnicianDashboardScreenState();
}

class _TechnicianDashboardScreenState extends State<TechnicianDashboardScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _tickets = [];
  String _userName = 'Teknisi IT';
  String _selectedFilter = 'ALL'; // ALL, OPEN, IN_PROGRESS, RESOLVED

  @override
  void initState() {
    super.initState();
    _loadUser();
    _fetchTickets();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userName = prefs.getString('user_name') ?? 'Teknisi IT';
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_name');
    await prefs.remove('user_role');

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> _fetchTickets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      if (token.isEmpty) {
        setState(() {
          _errorMessage = 'Sesi login tidak valid. Silakan login ulang.';
          _isLoading = false;
        });
        return;
      }

      final cleanToken = token.startsWith('Bearer ')
          ? token.substring(7).trim()
          : token.trim();

      // Coba ambil dari /api/tickets/all (endpoint seluruh tiket untuk dashboard)
      http.Response response = await http.get(
        Uri.parse('http://10.0.2.2:8080/api/tickets/all'),
        headers: {
          'Authorization': 'Bearer $cleanToken',
          'Content-Type': 'application/json',
        },
      );

      // Fallback jika /all tidak tersedia (misal 403 atau 404), gunakan /my-tickets
      if (response.statusCode != 200) {
        response = await http.get(
          Uri.parse('http://10.0.2.2:8080/api/tickets/my-tickets'),
          headers: {
            'Authorization': 'Bearer $cleanToken',
            'Content-Type': 'application/json',
          },
        );
      }

      if (response.statusCode == 200) {
        final dynamic rawData = jsonDecode(response.body);
        List<dynamic> list = [];
        if (rawData is List) {
          list = rawData;
        } else if (rawData is Map && rawData['data'] is List) {
          list = rawData['data'];
        }

        final parsedTickets = list.map<Map<String, dynamic>>((t) {
          final id = t['ticketId']?.toString() ?? t['id']?.toString() ?? '-';
          final desc = t['description']?.toString() ??
              t['problem']?.toString() ??
              'Tidak ada deskripsi';

          // Ambil nama customer / pelapor
          String customerName = 'Pelanggan';
          if (t['customerName'] != null) {
            customerName = t['customerName'].toString();
          } else if (t['customer'] is Map) {
            customerName = t['customer']['fullName']?.toString() ??
                t['customer']['name']?.toString() ??
                'Pelanggan';
          }

          // Ambil kategori
          String category = 'Umum';
          if (t['categoryName'] != null) {
            category = t['categoryName'].toString();
          } else if (t['category'] is Map) {
            category = t['category']['categoryName']?.toString() ??
                t['category']['name']?.toString() ??
                'Umum';
          }

          final status = (t['currentStatus']?.toString() ??
                  t['status']?.toString() ??
                  'OPEN')
              .trim()
              .toUpperCase();

          final rawDate = t['reportDate'] ??
              t['createdAt'] ??
              t['created_at'] ??
              t['report_date'] ??
              t['date'] ??
              t['timestamp'];

          return {
            'id': id,
            'customerName': customerName,
            'description': desc,
            'category': category,
            'status': status,
            'formattedDate': _formatDate(rawDate),
          };
        }).toList();

        if (mounted) {
          setState(() {
            _tickets = parsedTickets;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Gagal memuat tiket (Status HTTP ${response.statusCode})';
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

  String _formatDate(dynamic rawDate) {
    if (rawDate == null) {
      final now = DateTime.now();
      return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }
    final dateStr = rawDate.toString().trim();
    if (dateStr.isEmpty) return 'Baru saja';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _updateTicketStatus(String ticketId, String newStatus) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final cleanToken = token.startsWith('Bearer ')
        ? token.substring(7).trim()
        : token.trim();

    try {
      final response = await http.patch(
        Uri.parse('http://10.0.2.2:8080/api/tickets/$ticketId/status'),
        headers: {
          'Authorization': 'Bearer $cleanToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status tiket #$ticketId diperbarui ke $newStatus'),
            backgroundColor: const Color(0xFF48CEA4),
            duration: const Duration(seconds: 2),
          ),
        );
        _fetchTickets();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal update status (HTTP ${response.statusCode})',
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui status: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showUpdateStatusSheet(
    BuildContext context,
    Map<String, dynamic> ticket,
  ) {
    final String ticketId = ticket['id'] ?? '-';
    final String currentStatus = ticket['status'] ?? 'OPEN';

    final options = [
      {
        'key': 'OPEN',
        'label': 'Open (Baru)',
        'color': const Color(0xFF3B82F6),
        'icon': Icons.fiber_new,
      },
      {
        'key': 'IN_PROGRESS',
        'label': 'In Progress (Sedang Dikerjakan)',
        'color': const Color(0xFFF59E0B),
        'icon': Icons.autorenew,
      },
      {
        'key': 'RESOLVED',
        'label': 'Resolved (Selesai Ditangani)',
        'color': const Color(0xFF48CEA4),
        'icon': Icons.check_circle_outline,
      },
      {
        'key': 'CLOSED',
        'label': 'Closed (Tiket Ditutup)',
        'color': const Color(0xFF64748B),
        'icon': Icons.lock_outline,
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                const SizedBox(height: 20),
                Text(
                  'Perbarui Status #$ticketId',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Status saat ini: $currentStatus',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),
                ...options.map((opt) {
                  final String key = opt['key'] as String;
                  final String label = opt['label'] as String;
                  final Color color = opt['color'] as Color;
                  final IconData icon = opt['icon'] as IconData;
                  final bool isCurrent = key == currentStatus;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? color.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      title: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.w500,
                          color: isCurrent ? color : const Color(0xFF1E293B),
                        ),
                      ),
                      trailing: isCurrent
                          ? Icon(Icons.check_circle, color: color, size: 20)
                          : const Icon(
                              Icons.chevron_right,
                              color: Color(0xFFCBD5E1),
                              size: 18,
                            ),
                      onTap: () {
                        Navigator.pop(ctx);
                        if (!isCurrent) {
                          _updateTicketStatus(ticketId, key);
                        }
                      },
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return const Color(0xFF3B82F6);
      case 'IN_PROGRESS':
      case 'IN PROGRESS':
        return const Color(0xFFF59E0B);
      case 'RESOLVED':
        return const Color(0xFF48CEA4);
      case 'CLOSED':
      case 'DONE':
        return const Color(0xFF64748B);
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> get _filteredTickets {
    if (_selectedFilter == 'ALL') return _tickets;
    if (_selectedFilter == 'IN_PROGRESS') {
      return _tickets
          .where(
            (t) =>
                t['status'] == 'IN_PROGRESS' || t['status'] == 'IN PROGRESS',
          )
          .toList();
    }
    return _tickets.where((t) => t['status'] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final int openCount = _tickets.where((t) => t['status'] == 'OPEN').length;
    final int inProgressCount = _tickets
        .where(
          (t) => t['status'] == 'IN_PROGRESS' || t['status'] == 'IN PROGRESS',
        )
        .length;
    final int resolvedCount =
        _tickets.where((t) => t['status'] == 'RESOLVED').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Technician Dashboard',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF48CEA4)),
            tooltip: 'Segarkan Tiket',
            onPressed: _fetchTickets,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFE11D48)),
            tooltip: 'Keluar',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF48CEA4),
          onRefresh: _fetchTickets,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Ringkas
                _buildHeaderBanner(),
                const SizedBox(height: 16),

                // Kartu Statistik / Ringkasan Tiket Masuk
                _buildStatsGrid(
                  total: _tickets.length,
                  open: openCount,
                  inProgress: inProgressCount,
                  resolved: resolvedCount,
                ),
                const SizedBox(height: 24),

                // Filter Tabs
                _buildFilterChips(),
                const SizedBox(height: 16),

                // Daftar Tiket
                _buildTicketsList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF48CEA4).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.engineering_rounded,
              color: Color(0xFF48CEA4),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, $_userName 👋',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Kelola & tindak lanjuti laporan kendala teknis',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid({
    required int total,
    required int open,
    required int inProgress,
    required int resolved,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            label: 'Total Masuk',
            count: total,
            color: const Color(0xFF1E293B),
            icon: Icons.confirmation_number_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatItem(
            label: 'Open',
            count: open,
            color: const Color(0xFF3B82F6),
            icon: Icons.fiber_new,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatItem(
            label: 'Diproses',
            count: inProgress,
            color: const Color(0xFFF59E0B),
            icon: Icons.autorenew,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatItem(
            label: 'Selesai',
            count: resolved,
            color: const Color(0xFF48CEA4),
            icon: Icons.check_circle_outline,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'ALL', 'label': 'Semua'},
      {'key': 'OPEN', 'label': 'Open'},
      {'key': 'IN_PROGRESS', 'label': 'In Progress'},
      {'key': 'RESOLVED', 'label': 'Resolved'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                f['label']!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  color:
                      isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF48CEA4),
              backgroundColor: Colors.white,
              elevation: isSelected ? 1 : 0,
              pressElevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF48CEA4)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              onSelected: (_) {
                setState(() {
                  _selectedFilter = f['key']!;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTicketsList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: Color(0xFF48CEA4)),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 44, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.redAccent),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF48CEA4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _fetchTickets,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    final filtered = _filteredTickets;

    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum ada tiket masuk',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedFilter == 'ALL'
                  ? 'Saat ini belum ada tiket keluhan yang dilaporkan.'
                  : 'Tidak ada tiket dengan status $_selectedFilter.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final ticket = filtered[index];
        return _buildTicketCard(ticket);
      },
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final String id = ticket['id'] ?? '-';
    final String customer = ticket['customerName'] ?? 'Pelanggan';
    final String description = ticket['description'] ?? '-';
    final String category = ticket['category'] ?? 'Umum';
    final String status = ticket['status'] ?? 'OPEN';
    final String date = ticket['formattedDate'] ?? '-';

    final Color statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            // Aksi klik kartu untuk melihat detail tiket
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TicketDetailScreen(
                  ticketId: id,
                  problem: description,
                  status: status,
                  createdAt: date,
                ),
              ),
            );
            if (mounted) {
              _fetchTickets();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Kartu: Ticket ID & Badge Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.tag,
                          size: 16,
                          color: Color(0xFF48CEA4),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          id,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Nama Pelapor
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 15,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      customer,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Deskripsi Masalah
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Footer Kartu: Kategori, Tanggal, dan Tombol Ubah Status
                Row(
                  children: [
                    // Badge Kategori
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.category_outlined,
                            size: 13,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            category,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Tanggal Laporan
                    Expanded(
                      child: Text(
                        date,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Tombol Aksi Ubah Status
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(
                          color: Color(0xFF48CEA4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(
                        Icons.edit_note,
                        size: 16,
                        color: Color(0xFF48CEA4),
                      ),
                      label: const Text(
                        'Ubah Status',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF48CEA4),
                        ),
                      ),
                      onPressed: () {
                        _showUpdateStatusSheet(context, ticket);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
