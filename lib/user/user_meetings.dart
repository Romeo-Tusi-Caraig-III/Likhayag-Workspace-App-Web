// lib/user/user_meetings.dart
// Enhanced version with admin design but view-only for users
// Emerald gradient theme, improved UX, filtering by user's assigned meetings

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import '../services/api_service.dart';

// Global emerald gradient colors
const Color themeStart = Color(0xFF10B981); // emerald-500
const Color themeEnd = Color(0xFF059669); // emerald-600

class Meeting {
  String id;
  String title;
  String type;
  String? purpose;
  DateTime datetime;
  String? location;
  String? meetLink;
  String status;
  List<String> attendees;

  Meeting({
    required this.id,
    required this.title,
    this.type = 'project',
    this.purpose,
    required this.datetime,
    this.location,
    this.meetLink,
    this.status = 'Not Started',
    this.attendees = const [],
  });

  bool get isVirtual => meetLink != null && meetLink!.trim().isNotEmpty;

  factory Meeting.fromApi(Map<String, dynamic> m) {
  // Parse attendees - handle both objects and strings
  List<String> attendeesList = [];
  if (m['attendees'] != null) {
    if (m['attendees'] is List) {
      final rawAttendees = m['attendees'] as List;
      attendeesList = rawAttendees.map((a) {
        // Handle if attendees are objects with name/email
        if (a is Map) {
          return a['name']?.toString() ?? a['email']?.toString() ?? 'Unknown';
        }
        // Handle if attendees are already strings
        return a.toString();
      }).toList();
    }
  }

    print('📅 Parsing meeting: ${m['title']} - ${m['datetime']} - Attendees: ${attendeesList.length}');

  return Meeting(
    id: m['id'].toString(),
    title: m['title'] ?? '',
    type: m['type'] ?? 'project',
    purpose: m['purpose'],
    datetime: DateTime.parse(m['datetime']),
    location: m['location'] ?? m['Location'],
    meetLink: m['meetLink'] ?? m['meet_link'],
    status: m['status'] ?? 'Not Started',
    attendees: attendeesList,
    );
  }
}

class UserMeetingsPage extends StatefulWidget {
  const UserMeetingsPage({super.key});

  @override
  State<UserMeetingsPage> createState() => _UserMeetingsPageState();
}

class _UserMeetingsPageState extends State<UserMeetingsPage> {
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _displayFormat = DateFormat('EEE, MMM d, h:mm a');

  final List<Meeting> _meetings = [];
  String _search = '';
  bool _isLoading = false;
  bool _isRefreshing = false;

  final int _maxVisibleMeetings = 6;
  bool _showMoreMeetings = false;

  String _filterStatus = 'all'; // all, upcoming, completed, in_progress

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      if (mounted) setState(() => _search = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // API automatically filters meetings for the logged-in user
      final data = await ApiService.getMeetings();

      if (!mounted) return;

      setState(() {
        _meetings
          ..clear()
          ..addAll(data.map((m) => Meeting.fromApi(m)));
        _isLoading = false;
      });
      
      print('🎯 Loaded ${_meetings.length} meetings total');
      print('🎯 Filtered meetings: ${filteredMeetings.length}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack("Failed to load meetings: $e");
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final data = await ApiService.getMeetings();

      if (!mounted) return;

      setState(() {
        _meetings
          ..clear()
          ..addAll(data.map((m) => Meeting.fromApi(m)));
        _isRefreshing = false;
      });

      _showSnack('Meetings refreshed');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRefreshing = false);
      _showSnack("Failed to refresh: $e");
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  List<Meeting> get filteredMeetings {
    var result = _meetings;

    // Apply status filter
    if (_filterStatus != 'all') {
      final now = DateTime.now();
      result = result.where((m) {
        switch (_filterStatus) {
          case 'upcoming':
            return m.datetime.isAfter(now) && m.status != 'Completed';
          case 'completed':
            return m.status == 'Completed';
          case 'in_progress':
            return m.status == 'In Progress';
          default:
            return true;
        }
      }).toList();
    }

    // Apply search filter
    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      result = result.where((m) {
        return m.title.toLowerCase().contains(q) ||
            (m.purpose ?? '').toLowerCase().contains(q) ||
            (m.location ?? '').toLowerCase().contains(q);
      }).toList();
    }

    return result;
  }

  int get _upcoming7Days {
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 7));
    return _meetings
        .where((m) => m.datetime.isAfter(now) && m.datetime.isBefore(cutoff))
        .length;
  }

  List<Meeting> get _nextUp {
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 7));
    final list = _meetings
        .where((m) => m.datetime.isAfter(now) && m.datetime.isBefore(cutoff))
        .toList();
    list.sort((a, b) => a.datetime.compareTo(b.datetime));
    return list.take(3).toList();
  }

  int _countByStatus(String status) {
    if (status == 'upcoming') {
      final now = DateTime.now();
      return _meetings
          .where((m) => m.datetime.isAfter(now) && m.status != 'Completed')
          .length;
    }
    return _meetings.where((m) => m.status == status).length;
  }

  int get _virtualCount {
    return _meetings.where((m) => m.isVirtual).length;
  }

  void _openMeetingDetails(Meeting m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with close button
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        m.title,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient:
                              const LinearGradient(colors: [themeStart, themeEnd]),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 3))
                          ],
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(m.status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(m.status),
                          size: 16, color: _statusColor(m.status)),
                      const SizedBox(width: 6),
                      Text(
                        m.status,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _statusColor(m.status)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Details
                _detailRow(Icons.access_time, 'Date & Time',
                    _displayFormat.format(m.datetime)),
                const SizedBox(height: 12),
                _detailRow(Icons.category, 'Type', m.type),

                if (m.location != null && m.location!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _detailRow(Icons.place, 'Location', m.location!),
                ],

                if (m.purpose != null && m.purpose!.trim().isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text('Purpose',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(m.purpose!,
                      style: TextStyle(color: Colors.grey.shade700)),
                ],

                if (m.attendees.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text('Attendees',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: m.attendees
                        .map((a) => Chip(
                              label: Text(a),
                              backgroundColor: const Color(0xFFF0FDF4),
                              labelStyle:
                                  const TextStyle(color: Color(0xFF065F46)),
                            ))
                        .toList(),
                  ),
                ],

                // Join button for virtual meetings
                if (m.isVirtual) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: _GradientButton(
                      onPressed: () => _joinMeeting(m),
                      icon: Icons.video_call,
                      label: 'Join Meeting',
                    ),
                  ),
                ],

                const SizedBox(height: 26),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: themeStart, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 3),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _joinMeeting(Meeting m) async {
    final link = m.meetLink;
    if (link == null || link.trim().isEmpty) {
      _showSnack('No meeting link available');
      return;
    }

    final uri = Uri.tryParse(link);
    if (uri == null) {
      _showSnack('Invalid meeting link');
      return;
    }

    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showSnack('Could not open meeting link');
      }
    } catch (e) {
      _showSnack('Error opening link: $e');
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'in progress':
        return Icons.play_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredMeetings;
    final visible = _showMoreMeetings
        ? filtered
        : filtered.take(_maxVisibleMeetings).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF7),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card - Next Up
                _buildHeaderCard(),
                const SizedBox(height: 18),

                // Search bar with filter
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search meetings...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Clear',
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _search = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                      onPressed:
                          (_isLoading || _isRefreshing) ? null : _refreshData,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _filterChip('Upcoming', 'upcoming'),
                      const SizedBox(width: 8),
                      _filterChip('In Progress', 'in_progress'),
                      const SizedBox(width: 8),
                      _filterChip('Completed', 'completed'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Stats tiles
                _buildStatTiles(),
                const SizedBox(height: 12),

                const Text('My Meetings',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),

                // Meeting list
                if (_isLoading)
                  _buildShimmerPlaceholders()
                else if (filtered.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.event_busy,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            _search.isNotEmpty
                                ? 'No meetings found matching "$_search"'
                                : 'No meetings assigned to you',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 15),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...visible.map((m) => MeetingCard(
                        meeting: m,
                        dateFormat: _displayFormat,
                        onTap: () => _openMeetingDetails(m),
                        onJoin: m.isVirtual ? () => _joinMeeting(m) : null,
                      )),

                if (filtered.length > _maxVisibleMeetings)
                  Center(
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _showMoreMeetings = !_showMoreMeetings),
                      child: Text(_showMoreMeetings
                          ? 'Show less'
                          : 'Show more (${filtered.length - _maxVisibleMeetings} more)'),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [themeStart, themeEnd]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: themeEnd.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.schedule, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next Up',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18),
                ),
                const SizedBox(height: 8),
                if (_nextUp.isEmpty)
                  const Text('No upcoming meetings in next 7 days',
                      style: TextStyle(color: Colors.white70, fontSize: 13))
                else
                  ..._nextUp.map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(top: 6),
                                decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(m.title,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Text(DateFormat('MMM d').format(m.datetime),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      )),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text('$_upcoming7Days',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20)),
                const Text('upcoming',
                    style: TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTiles() {
    Widget tile(String title, String count, IconData icon, Color color) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: Colors.grey.shade700, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(count,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: tile('Not Started',
                    '${_countByStatus('Not Started')}', Icons.schedule, Colors.orange)),
            const SizedBox(width: 12),
            Expanded(
                child: tile('This Week', '$_upcoming7Days',
                    Icons.calendar_today, themeStart)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: tile('In Progress', '${_countByStatus('In Progress')}',
                    Icons.play_circle, Colors.blue)),
            const SizedBox(width: 12),
            Expanded(
                child: tile('Virtual', '$_virtualCount', Icons.video_call,
                    const Color(0xFF7C3AED))),
          ],
        ),
      ],
    );
  }

  Widget _buildShimmerPlaceholders() {
    return Column(
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterStatus = selected ? value : 'all');
      },
      selectedColor: themeStart,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
            color: isSelected ? themeStart : Colors.grey.shade300),
      ),
    );
  }
}

class MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final VoidCallback? onJoin;

  const MeetingCard({
    super.key,
    required this.meeting,
    required this.dateFormat,
    required this.onTap,
    this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final tags = <Widget>[];
    if (meeting.type.isNotEmpty) tags.add(_tag(context, meeting.type));
    if (meeting.isVirtual) tags.add(_tag(context, 'Virtual'));

    final location = (meeting.location ?? '').trim().isNotEmpty
        ? meeting.location!
        : (meeting.isVirtual ? 'Online' : '');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meeting.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusColor(meeting.status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon(meeting.status),
                            size: 12,
                            color: _statusColor(meeting.status)),
                        const SizedBox(width: 4),
                        Text(
                          meeting.status,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              color: _statusColor(meeting.status)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: tags),
              if (meeting.purpose != null && meeting.purpose!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  meeting.purpose!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      [
                        dateFormat.format(meeting.datetime),
                        if (location.isNotEmpty) '•',
                        if (location.isNotEmpty) location
                      ].join(' '),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
                  if (onJoin != null)
                    _GradientPill(
                      onPressed: onJoin!,
                      icon: Icons.video_call,
                      label: 'Join',
                    )
                  else
                    const Icon(Icons.chevron_right, color: themeStart),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'in progress':
        return Icons.play_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  Widget _tag(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: themeStart.withOpacity(0.12)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF065F46),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GradientPill extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData? icon;
  final String label;

  const _GradientPill({
    required this.onPressed,
    this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [themeStart, themeEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: themeEnd.withOpacity(0.18),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData? icon;
  final String label;

  const _GradientButton({
    required this.onPressed,
    this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [themeStart, themeEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: themeEnd.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}