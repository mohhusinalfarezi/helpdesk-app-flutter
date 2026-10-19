import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_screen.dart';
import 'ticket_chat_screen.dart';
import 'ticket_detail_screen.dart';
import 'notification_screen.dart';
import '../widgets/rating_dialog.dart';

// ────────────────────────────────────────────────────────────
// Enum untuk opsi sort
// ────────────────────────────────────────────────────────────
enum SortOption { newest, oldest, az, za }

class TicketTrackerScreen extends StatefulWidget {
  const TicketTrackerScreen({super.key});

  @override
  State<TicketTrackerScreen> createState() => _TicketTrackerScreenState();
}

class _TicketTrackerScreenState extends State<TicketTrackerScreen> {
  // ── Warna tema ─────────────────────────────────────────────
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color mintGreen = Color(0xFF48CEA4);
  static const Color navySlate = Color(0xFF1E293B);
  static const Color greyText = Color(0xFF94A3B8);

  // ── State utama ────────────────────────────────────────────
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _tickets = [];
  String _userName = "Pengguna";

  int _activeTicketsCount = 0;
  int _resolvedTicketsCount = 0;

  // ── State search / sort / filter ───────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortOption _currentSort = SortOption.newest;
  String _currentFilter = 'ALL'; // ALL, OPEN, IN_PROGRESS, RESOLVED, CLOSED

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _fetchTicketsData();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Memuat nama user dari SharedPreferences ────────────────
  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? "Pengguna";
    });
  }

  // ── Greeting berdasarkan waktu & lokalisasi ────────────────
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'greeting_morning'.tr();
    if (hour < 15) return 'greeting_afternoon'.tr();
    if (hour < 18) return 'greeting_evening'.tr();
    return 'greeting_night'.tr();
  }

  // ── Fetch tiket dari API ──────────────────────────────────
  Future<void> _fetchTicketsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      debugPrint('=== ISI TOKEN DARI MEMORI: $token ===');

      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = 'session_invalid'.tr();
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('http://10.0.2.2:8080/api/tickets/my-tickets'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;

        int active = 0;
        int resolved = 0;

        for (var t in data) {
          String status = (t['currentStatus']?.toString() ??
                  t['status']?.toString() ??
                  'OPEN')
              .trim()
              .toUpperCase();

          if (status == 'OPEN' ||
              status == 'IN PROGRESS' ||
              status == 'IN_PROGRESS') {
            active++;
          } else if (status == 'RESOLVED' ||
              status == 'CLOSED' ||
              status == 'DONE') {
            resolved++;
          }
        }

        setState(() {
          _tickets = data;
          _activeTicketsCount = active;
          _resolvedTicketsCount = resolved;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'api_load_failed'.tr(args: [response.statusCode.toString()]);
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

  // ── Helper: normalisasi status ─────────────────────────────
  String _normalizeStatus(dynamic ticket) {
    return (ticket['currentStatus']?.toString() ??
            ticket['status']?.toString() ??
            'OPEN')
        .trim()
        .toUpperCase()
        .replaceAll(' ', '_'); // "IN PROGRESS" → "IN_PROGRESS"
  }

  // ── Helper: ambil judul tiket ──────────────────────────────
  String _getTicketTitle(dynamic ticket) {
    return ticket['description']?.toString() ??
        ticket['problem']?.toString() ??
        'no_description'.tr();
  }

  // ── Helper: parse tanggal tiket ────────────────────────────
  DateTime? _parseTicketDate(dynamic ticket) {
    final dynamic rawDate = ticket['createdAt'] ??
        ticket['created_at'] ??
        ticket['report_date'] ??
        ticket['reportDate'] ??
        ticket['created_date'] ??
        ticket['date'] ??
        ticket['timestamp'];

    if (rawDate != null && rawDate.toString().trim().isNotEmpty) {
      try {
        return DateTime.parse(rawDate.toString().trim()).toLocal();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // ── Format tanggal untuk tampilan ──────────────────────────
  String _formatDate(dynamic ticket) {
    final dt = _parseTicketDate(ticket);
    if (dt != null) {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  // ── Filtering + Searching + Sorting logic ─────────────────
  List<dynamic> get _processedTickets {
    List<dynamic> result = List<dynamic>.from(_tickets);

    // 1. Filter berdasarkan status
    if (_currentFilter != 'ALL') {
      result = result.where((t) {
        final status = _normalizeStatus(t);
        if (_currentFilter == 'RESOLVED') {
          return status == 'RESOLVED' || status == 'DONE';
        }
        return status == _currentFilter;
      }).toList();
    }

    // 2. Filter berdasarkan pencarian (ID atau deskripsi)
    if (_searchQuery.isNotEmpty) {
      result = result.where((t) {
        final id = (t['ticketId']?.toString() ?? '').toLowerCase();
        final title = _getTicketTitle(t).toLowerCase();
        return id.contains(_searchQuery) || title.contains(_searchQuery);
      }).toList();
    }

    // 3. Sort
    switch (_currentSort) {
      case SortOption.newest:
        result.sort((a, b) {
          final da = _parseTicketDate(a) ?? DateTime(2000);
          final db = _parseTicketDate(b) ?? DateTime(2000);
          return db.compareTo(da);
        });
        break;
      case SortOption.oldest:
        result.sort((a, b) {
          final da = _parseTicketDate(a) ?? DateTime(2000);
          final db = _parseTicketDate(b) ?? DateTime(2000);
          return da.compareTo(db);
        });
        break;
      case SortOption.az:
        result.sort((a, b) => _getTicketTitle(a)
            .toLowerCase()
            .compareTo(_getTicketTitle(b).toLowerCase()));
        break;
      case SortOption.za:
        result.sort((a, b) => _getTicketTitle(b)
            .toLowerCase()
            .compareTo(_getTicketTitle(a).toLowerCase()));
        break;
    }

    return result;
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: mintGreen))
            : RefreshIndicator(
                color: mintGreen,
                onRefresh: _fetchTicketsData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 24),
                      _buildPriorityCard(),
                      const SizedBox(height: 16),
                      _buildStatsRow(),
                      const SizedBox(height: 24),
                      _buildSearchBar(),
                      const SizedBox(height: 16),
                      _buildSortAndFilterRow(),
                      const SizedBox(height: 8),
                      _buildFilterChips(),
                      const SizedBox(height: 24),
                      _buildRecentTicketsHeader(),
                      const SizedBox(height: 16),
                      _buildTicketContent(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
          if (mounted) {
            _fetchTicketsData();
          }
        },
        backgroundColor: mintGreen,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: navySlate,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: const TextStyle(color: greyText, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _userName,
                  style: const TextStyle(
                    color: navySlate,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: const Icon(
                  Icons.notifications_none,
                  color: navySlate,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const CircleAvatar(
              radius: 18,
              backgroundColor: mintGreen,
              child: Icon(Icons.person, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  // ── Priority Card (Kartu hijau) ───────────────────────────
  Widget _buildPriorityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: mintGreen,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: mintGreen.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: navySlate, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'helpdesk_priority'.tr(),
                    style: TextStyle(
                      color: navySlate.withValues(alpha: 0.8),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: navySlate.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'live_update'.tr(),
                    style: TextStyle(
                      color: navySlate.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$_activeTicketsCount ${'active_tickets_count'.tr()}',
            style: const TextStyle(
              color: navySlate,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _activeTicketsCount > 0
                ? 'active_issues_exist'.tr()
                : 'all_systems_operational'.tr(),
            style: TextStyle(
              color: navySlate.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Baris statistik ────────────────────────────────────────
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'total_tickets'.tr(),
            _tickets.length.toString(),
            Icons.receipt_long_outlined,
            const Color(0xFF448AFF),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'resolved_tickets'.tr(),
            _resolvedTicketsCount.toString(),
            Icons.check_circle_outline,
            mintGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: greyText,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: navySlate,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  SEARCH BAR
  // ══════════════════════════════════════════════════════════
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 14, color: navySlate),
        decoration: InputDecoration(
          hintText: 'search_ticket_hint'.tr(),
          hintStyle: const TextStyle(color: greyText, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: greyText, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                  },
                  child: const Icon(Icons.close, color: greyText, size: 18),
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  SORT DROPDOWN + JUMLAH HASIL
  // ══════════════════════════════════════════════════════════
  Widget _buildSortAndFilterRow() {
    final processed = _processedTickets;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Jumlah hasil
        Text(
          '${processed.length} ${'recent_tickets'.tr()}',
          style: const TextStyle(
            color: greyText,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        // Sort dropdown
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<SortOption>(
              value: _currentSort,
              icon: const Icon(Icons.unfold_more, size: 16, color: greyText),
              isDense: true,
              style: const TextStyle(fontSize: 12, color: navySlate),
              items: [
                DropdownMenuItem(
                  value: SortOption.newest,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_downward,
                          size: 14, color: mintGreen),
                      const SizedBox(width: 6),
                      Text('sort_newest'.tr()),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: SortOption.oldest,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_upward,
                          size: 14, color: mintGreen),
                      const SizedBox(width: 6),
                      Text('sort_oldest'.tr()),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: SortOption.az,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort_by_alpha,
                          size: 14, color: mintGreen),
                      const SizedBox(width: 6),
                      Text('sort_az'.tr()),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: SortOption.za,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort_by_alpha,
                          size: 14, color: mintGreen),
                      const SizedBox(width: 6),
                      Text('sort_za'.tr()),
                    ],
                  ),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _currentSort = val);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  FILTER CHIPS  (Horizontal scrollable)
  // ══════════════════════════════════════════════════════════
  Widget _buildFilterChips() {
    final filters = <Map<String, dynamic>>[
      {
        'key': 'ALL',
        'label': 'filter_all',
        'icon': Icons.all_inclusive,
        'color': navySlate,
      },
      {
        'key': 'OPEN',
        'label': 'filter_open',
        'icon': Icons.error_outline,
        'color': const Color(0xFFFF5252),
      },
      {
        'key': 'IN_PROGRESS',
        'label': 'filter_in_progress',
        'icon': Icons.hourglass_top,
        'color': const Color(0xFF448AFF),
      },
      {
        'key': 'RESOLVED',
        'label': 'filter_resolved',
        'icon': Icons.check_circle_outline,
        'color': mintGreen,
      },
      {
        'key': 'CLOSED',
        'label': 'filter_closed',
        'icon': Icons.lock_outline,
        'color': const Color(0xFF78909C),
      },
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = filters[index];
          final isActive = _currentFilter == f['key'];
          final Color chipColor = f['color'] as Color;

          return GestureDetector(
            onTap: () {
              setState(() => _currentFilter = f['key'] as String);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? chipColor.withValues(alpha: 0.12)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? chipColor.withValues(alpha: 0.5)
                      : Colors.grey.withValues(alpha: 0.15),
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    f['icon'] as IconData,
                    size: 14,
                    color: isActive ? chipColor : greyText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    (f['label'] as String).tr(),
                    style: TextStyle(
                      color: isActive ? chipColor : greyText,
                      fontSize: 12,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Recent Tickets header ─────────────────────────────────
  Widget _buildRecentTicketsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'recent_tickets'.tr(),
          style: const TextStyle(
            color: navySlate,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        GestureDetector(
          onTap: _fetchTicketsData,
          child: Row(
            children: [
              const Icon(Icons.refresh, size: 16, color: mintGreen),
              const SizedBox(width: 4),
              Text(
                'refresh'.tr(),
                style: TextStyle(
                  color: mintGreen.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  KONTEN TIKET (termasuk state kosong & error)
  // ══════════════════════════════════════════════════════════
  Widget _buildTicketContent() {
    // Error state
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
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Tidak ada tiket sama sekali
    if (_tickets.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, size: 40, color: Colors.grey),
            const SizedBox(height: 8),
            Text(
              'no_tickets_created'.tr(),
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Ada tiket tapi setelah filter/search tidak ada yang cocok
    final processed = _processedTickets;
    if (processed.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.search_off, size: 44, color: greyText),
            const SizedBox(height: 12),
            Text(
              'no_tickets_found'.tr(),
              style: const TextStyle(
                color: navySlate,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'no_tickets_match'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: greyText, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // List tiket
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: processed.length,
      itemBuilder: (context, index) {
        final ticket = processed[index];
        final String id = ticket['ticketId']?.toString() ?? '-';
        final String status = _normalizeStatus(ticket);
        final String displayStatus = status.replaceAll('_', ' ');
        final String title = _getTicketTitle(ticket);
        final String time = _formatDate(ticket);

        // Warna & ikon berdasarkan status
        Color sColor;
        Color sBgColor;
        IconData statusIcon;
        switch (status) {
          case 'OPEN':
            sColor = const Color(0xFFFF5252);
            sBgColor = const Color(0xFFFF5252).withValues(alpha: 0.1);
            statusIcon = Icons.error_outline;
            break;
          case 'IN_PROGRESS':
            sColor = const Color(0xFF448AFF);
            sBgColor = const Color(0xFF448AFF).withValues(alpha: 0.1);
            statusIcon = Icons.hourglass_top;
            break;
          case 'CLOSED':
            sColor = const Color(0xFF78909C);
            sBgColor = const Color(0xFF78909C).withValues(alpha: 0.1);
            statusIcon = Icons.lock_outline;
            break;
          default: // RESOLVED / DONE
            sColor = mintGreen;
            sBgColor = mintGreen.withValues(alpha: 0.1);
            statusIcon = Icons.check_circle_outline;
        }

        return Column(
          children: [
            _buildTicketItem(
              id: id,
              status: displayStatus,
              title: title,
              category: 'IT Support',
              time: time,
              statusColor: sColor,
              statusBgColor: sBgColor,
              statusIcon: statusIcon,
              ticket: ticket,
            ),
            if (index < processed.length - 1) const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  // ── Widget per-item tiket ─────────────────────────────────
  Widget _buildTicketItem({
    required String id,
    required String status,
    required String title,
    required String category,
    required String time,
    required Color statusColor,
    required Color statusBgColor,
    required IconData statusIcon,
    required dynamic ticket,
  }) {
    final bool isResolved = status.toUpperCase() == 'RESOLVED' ||
        status.toUpperCase() == 'DONE';
    final dynamic rawRating = ticket['rating'];
    final int? rating = (rawRating is num)
        ? rawRating.toInt()
        : int.tryParse(rawRating?.toString() ?? '');
    final bool hasReviewed = rating != null && rating > 0;

    // DIBUNGKUS GESTURE DETECTOR AGAR BISA DIKLIK
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TicketDetailScreen(
              ticketId: id,
              problem: title,
              status: status,
              createdAt: time,
              ticketData: ticket,
            ),
          ),
        );
        if (mounted) {
          _fetchTicketsData();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.confirmation_num_outlined,
                      color: mintGreen,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      id,
                      style: const TextStyle(
                        color: greyText,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: navySlate,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child:
                  Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.folder_open, color: greyText, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      category,
                      style: const TextStyle(color: greyText, fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: greyText, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      time.length > 10 ? time.substring(0, 10) : time,
                      style: const TextStyle(color: greyText, fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    // Tombol Chat
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TicketChatScreen(
                              ticketId: id,
                              ticketCode: id,
                              ticketTitle: title,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: mintGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline,
                          size: 16,
                          color: mintGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Tombol atau Badge Rating & Feedback untuk tiket RESOLVED
            if (isResolved) ...[
              if (hasReviewed)
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (starIdx) {
                          return Icon(
                            starIdx < rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 18,
                            color: const Color(0xFFFFB800),
                          );
                        }),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'already_reviewed'.tr(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 14.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showRatingDialog(
                          context,
                          ticket,
                          onSuccess: _fetchTicketsData,
                        );
                      },
                      icon: const Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: Color(0xFFD97706),
                      ),
                      label: Text(
                        'give_feedback'.tr(),
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFFFEF3C7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFFFDE68A)),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
