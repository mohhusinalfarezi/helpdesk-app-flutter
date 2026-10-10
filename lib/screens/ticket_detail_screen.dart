import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;
  final String problem;
  final String status;
  final String createdAt;

  const TicketDetailScreen({
    super.key,
    required this.ticketId,
    required this.problem,
    required this.status,
    required this.createdAt,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  late String _problem;
  late String _status;
  late String _createdAt;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _problem = widget.problem;
    _status = widget.status;
    _createdAt = widget.createdAt;
    _fetchTicketDetails();
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
        final response = await http.get(
          Uri.parse('http://10.0.2.2:8080/api/tickets/my-tickets'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final dynamic matched = data.firstWhere(
            (t) =>
                t['ticketId']?.toString() == widget.ticketId ||
                t['id']?.toString() == widget.ticketId,
            orElse: () => null,
          );

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

            setState(() {
              _status = newStatus;
              _problem = newProblem;
              if (newDate.isNotEmpty) {
                _createdAt = newDate;
              }
            });
          }
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
                            const Expanded(
                              child: Center(
                                child: Text(
                                  'Ticket Details',
                                  style: TextStyle(
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
                            // Department Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.support_agent,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'IT Support',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
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
                        const Text(
                          'Issue Description',
                          style: TextStyle(
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
                      const Text(
                        'Ticket Progress',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildTimelineStep(
                        title: 'Ticket Created',
                        subtitle: 'Sistem telah menerima keluhan',
                        isActive: true,
                        isLast: false,
                      ),
                      _buildTimelineStep(
                        title: 'In Progress',
                        subtitle: 'Sedang ditangani oleh tim teknisi',
                        isActive: _status.toUpperCase() == 'IN_PROGRESS' ||
                            _status.toUpperCase() == 'IN PROGRESS' ||
                            isResolved,
                        isLast: false,
                      ),
                      _buildTimelineStep(
                        title: 'Resolved',
                        subtitle: 'Masalah telah diselesaikan',
                        isActive: isResolved,
                        isLast: true,
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
