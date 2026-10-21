import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/rating_dialog.dart';
import 'package:helpdesk_app/config/api_config.dart';

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;
  final String problem;
  final String status;
  final String createdAt;
  final dynamic ticketData;
  final String? technicianName;

  const TicketDetailScreen({
    super.key,
    required this.ticketId,
    required this.problem,
    required this.status,
    required this.createdAt,
    this.ticketData,
    this.technicianName,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  late String _problem;
  late String _status;
  late String _createdAt;
  bool _isRefreshing = false;
  dynamic _ticketData;
  String? _technicianName;
  int? _rating;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _problem = widget.problem;
    _status = widget.status;
    _createdAt = widget.createdAt;
    _technicianName = widget.technicianName;
    if (widget.ticketData != null) {
      _ticketData = widget.ticketData;
      _technicianName ??= _extractTechnicianName(_ticketData);
    }
    _fetchTicketDetails();
  }

  String? _extractTechnicianName(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      final name = data['technicianName'] ??
          data['technician_name'] ??
          data['assignedTechnician'] ??
          (data['technician'] is Map
              ? (data['technician']['technicianName'] ??
                  data['technician']['name'])
              : null);
      if (name != null && name.toString().trim().isNotEmpty) {
        return name.toString().trim();
      }
    }
    return null;
  }

  Future<void> _fetchTicketDetails() async {
    if (!mounted) return;
    setState(() {
      _isRefreshing = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token != null && token.isNotEmpty) {
        dynamic matched;

        // 1. Coba ambil dari endpoint detail spesifik /api/tickets/{ticketId}
        try {
          final detailRes = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/api/tickets/${widget.ticketId}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
          if (detailRes.statusCode == 200) {
            matched = json.decode(detailRes.body);
          }
        } catch (_) {}

        // 2. Fallback ke /my-tickets jika belum didapat
        if (matched == null) {
          try {
            final response = await http.get(
              Uri.parse('${ApiConfig.baseUrl}/api/tickets/my-tickets'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
            if (response.statusCode == 200) {
              final List<dynamic> data = json.decode(response.body);
              matched = data.firstWhere(
                (t) =>
                    t['ticketId']?.toString() == widget.ticketId ||
                    t['id']?.toString() == widget.ticketId,
                orElse: () => null,
              );
            }
          } catch (_) {}
        }

        // 3. Fallback ke /all jika user adalah teknisi/admin
        if (matched == null) {
          try {
            final allRes = await http.get(
              Uri.parse('${ApiConfig.baseUrl}/api/tickets/all'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
            if (allRes.statusCode == 200) {
              final List<dynamic> allData = json.decode(allRes.body);
              matched = allData.firstWhere(
                (t) =>
                    t['ticketId']?.toString() == widget.ticketId ||
                    t['id']?.toString() == widget.ticketId,
                orElse: () => null,
              );
            }
          } catch (_) {}
        }

        if (matched != null && mounted) {
          final String newStatus = (matched['currentStatus']?.toString() ??
                  matched['status']?.toString() ??
                  _status)
              .trim()
              .toUpperCase();

          final String newProblem = matched['description']?.toString() ??
              matched['problem']?.toString() ??
              _problem;

          final dynamic rawDate = matched['reportDate'] ??
              matched['createdAt'] ??
              matched['created_at'] ??
              matched['report_date'] ??
              matched['date'] ??
              matched['timestamp'];

          String newDate = '';
          if (rawDate != null && rawDate.toString().trim().isNotEmpty) {
            final dateStr = rawDate.toString().trim();
            try {
              final dt = DateTime.parse(dateStr).toLocal();
              newDate =
                  '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            } catch (_) {
              newDate = dateStr;
            }
          }

          final dynamic rawRating = matched['rating'];
          final int? newRating = (rawRating is num)
              ? rawRating.toInt()
              : int.tryParse(rawRating?.toString() ?? '');
          final String? newFeedback = matched['feedback']?.toString();
          final String? fetchedTech = _extractTechnicianName(matched);

          setState(() {
            _status = newStatus;
            _problem = newProblem;
            _ticketData = matched;
            _rating = newRating;
            _feedback = newFeedback;
            if (fetchedTech != null && fetchedTech.isNotEmpty) {
              _technicianName = fetchedTech;
            }
            if (newDate.isNotEmpty) {
              _createdAt = newDate;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching ticket detail: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Color _getStatusColor() {
    switch (_status.toUpperCase()) {
      case 'OPEN':
        return const Color(0xFF3B82F6);
      case 'IN_PROGRESS':
      case 'IN PROGRESS':
        return const Color(0xFFF59E0B);
      case 'RESOLVED':
      case 'CLOSED':
      case 'DONE':
        return const Color(0xFF48CEA4);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final isResolved = _status.toUpperCase() == 'RESOLVED' ||
        _status.toUpperCase() == 'CLOSED' ||
        _status.toUpperCase() == 'DONE';

    final String? techName =
        _technicianName ?? _extractTechnicianName(_ticketData);
    final bool hasTechnician = techName != null && techName.trim().isNotEmpty;
    final String badgeText =
        hasTechnician ? techName.trim() : 'waiting_technician'.tr();
    final IconData badgeIcon = hasTechnician
        ? Icons.engineering_outlined
        : Icons.hourglass_empty_rounded;
    final Color badgeBg = hasTechnician
        ? const Color(0xFFE6F7F2)
        : const Color(0xFFFFF4ED);
    final Color badgeTextColor = hasTechnician
        ? const Color(0xFF0F766E)
        : const Color(0xFFC2410C);

    String displayDate = _createdAt.trim();
    if (displayDate.isEmpty || displayDate == 'Tanggal tidak tersedia') {
      final now = DateTime.now();
      displayDate =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        color: const Color(0xFF48CEA4),
        onRefresh: _fetchTicketDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // HEADER DENGAN TEMA HIJAU OVERLAP
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Background Header Hijau
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(
                      top: 60,
                      bottom: 80,
                      left: 24,
                      right: 24,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF48CEA4), Color(0xFF38B28B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context, true),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 4.0),
                                  child: Icon(
                                    Icons.arrow_back_ios,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'ticket_details_title'.tr(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: _isRefreshing ? null : _fetchTicketDetails,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: _isRefreshing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.refresh,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        Text(
                          '#${widget.ticketId}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _status.toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Teknisi Penanggung Jawab Badge (Informatif)
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      badgeIcon,
                                      color: badgeTextColor,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        badgeText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: badgeTextColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // KARTU ISSUE DESCRIPTION (OVERLAPPING)
                  Container(
                    margin: const EdgeInsets.only(top: 220, left: 24, right: 24),
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'issue_description'.tr(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _problem,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                            height: 1.5,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Divider(color: Color(0xFFF1F5F9)),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              displayDate,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // TIMELINE STATUS TRACKING
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
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
                      Text(
                        'ticket_progress'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildTimelineStep(
                        title: 'progress_created'.tr(),
                        subtitle: 'progress_created_desc'.tr(),
                        isActive: true,
                        isLast: false,
                      ),
                      _buildTimelineStep(
                        title: 'progress_in_progress'.tr(),
                        subtitle: 'progress_in_progress_desc'.tr(),
                        isActive: _status.toUpperCase() == 'IN_PROGRESS' ||
                            _status.toUpperCase() == 'IN PROGRESS' ||
                            isResolved,
                        isLast: false,
                      ),
                      _buildTimelineStep(
                        title: 'progress_resolved'.tr(),
                        subtitle: 'progress_resolved_desc'.tr(),
                        isActive: isResolved,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),

              // RATING & FEEDBACK SECTION JIKA TIKET RESOLVED
              if (isResolved)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    margin: const EdgeInsets.only(top: 24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _rating != null && _rating! > 0
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFFD97706),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'already_reviewed'.tr(),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: List.generate(5, (starIdx) {
                                      return Icon(
                                        starIdx < _rating!
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        size: 20,
                                        color: const Color(0xFFFFB800),
                                      );
                                    }),
                                  ),
                                ],
                              ),
                              if (_feedback != null &&
                                  _feedback!.trim().isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    '"$_feedback"',
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Color(0xFF475569),
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'rating_title'.tr(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'rating_subtitle'.tr(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    showRatingDialog(
                                      context,
                                      _ticketData ??
                                          {
                                            'id': widget.ticketId,
                                            'ticketId': widget.ticketId,
                                          },
                                      onSuccess: _fetchTicketDetails,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.star_rounded,
                                    size: 20,
                                    color: Color(0xFFD97706),
                                  ),
                                  label: Text(
                                    'give_feedback'.tr(),
                                    style: const TextStyle(
                                      color: Color(0xFF92400E),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: const Color(0xFFFEF3C7),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(
                                        color: Color(0xFFFDE68A),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF48CEA4)
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: isActive
                    ? Border.all(
                        color: const Color(0xFF48CEA4).withValues(alpha: 0.3),
                        width: 4,
                      )
                    : Border.all(color: Colors.grey.shade300, width: 2),
              ),
              child: isActive
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 45,
                color: isActive
                    ? const Color(0xFF48CEA4)
                    : Colors.grey.shade200,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isActive
                        ? const Color(0xFF1E293B)
                        : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
