// lib/user/user_meetings.dart
// Cleaned version: removed top AppBar, pills, info banners, enlarged Next Up icon box.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

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
    List<String> attendeesList = [];
    if (m['attendees'] != null) {
      if (m['attendees'] is List) attendeesList = List<String>.from(m['attendees']);
    }

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

  static const Color emeraldStart = Color(0xFF10B981);
  static const Color emeraldEnd = Color(0xFF059669);

  @override
  void initState() {
    super.initState();
    _loadData();
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
      final data = await ApiService.getMeetings();

      if (!mounted) return;

      setState(() {
        _meetings
          ..clear()
          ..addAll(data.map((m) => Meeting.fromApi(m)));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _isLoading = false;
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
    } catch (e) {
      if (!mounted) return;
      _isRefreshing = false;
      _showSnack("Failed to refresh: $e");
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  List<Meeting> get filteredMeetings {
    if (_search.trim().isEmpty) return _meetings;
    final q = _search.toLowerCase();
    return _meetings.where((m) => m.title.toLowerCase().contains(q)).toList();
  }

  int get _upcoming7Days {
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 7));
    return _meetings.where((m) => m.datetime.isAfter(now) && m.datetime.isBefore(cutoff)).length;
  }

  List<Meeting> get _nextUp {
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 7));
    final list = _meetings.where((m) => m.datetime.isAfter(now) && m.datetime.isBefore(cutoff)).toList();
    list.sort((a, b) => a.datetime.compareTo(b.datetime));
    return list.take(3).toList();
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      m.title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _detailRow(Icons.access_time, 'Date & Time', _displayFormat.format(m.datetime)),
              const SizedBox(height: 12),
              _detailRow(Icons.category, 'Type', m.type),
              const SizedBox(height: 12),
              _detailRow(Icons.info_outline, 'Status', m.status),
              if (m.location != null && m.location!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _detailRow(Icons.place, 'Location', m.location!),
              ],
              if (m.purpose != null && m.purpose!.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text('Purpose', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(m.purpose!),
              ],
              if (m.attendees.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text('Attendees', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: m.attendees.map((a) => Chip(label: Text(a))).toList(),
                ),
              ],
              const SizedBox(height: 26),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: emeraldStart),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 3),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredMeetings;
    final visible = _showMoreMeetings ? filtered : filtered.take(_maxVisibleMeetings).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF7),

      // NO AppBar → fully removed white space
      appBar: null,

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ⭐ Next Up Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [emeraldStart, emeraldEnd]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: emeraldEnd.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.schedule, size: 30, color: Colors.white),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Next Up',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18)),
                            const SizedBox(height: 6),
                            if (_nextUp.isEmpty)
                              const Text(
                                'No upcoming meetings in next 7 days',
                                style: TextStyle(color: Colors.white),
                              )
                            else
                              ..._nextUp.map(
                                (m) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          m.title,
                                          style: const TextStyle(
                                              color: Colors.white, fontSize: 13),
                                        ),
                                      ),
                                      Text(
                                        DateFormat('MMM d').format(m.datetime),
                                        style: const TextStyle(
                                            color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 🔎 Search bar
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _search = v),
                        decoration: InputDecoration(
                          hintText: 'Search meetings...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: _isLoading ? null : _refreshData,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                const Text('All Meetings',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 12),

                if (_isLoading)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ))
                else if (filtered.isEmpty)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('No meetings found'),
                  ))
                else
                  ...visible.map(
                    (m) => MeetingCard(
                      meeting: m,
                      dateFormat: _displayFormat,
                      onTap: () => _openMeetingDetails(m),
                    ),
                  ),

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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  const MeetingCard({
    super.key,
    required this.meeting,
    required this.dateFormat,
    required this.onTap,
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
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(meeting.status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      meeting.status,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: _statusColor(meeting.status)),
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
                  style: TextStyle(color: Colors.grey.shade700),
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
                          TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF10B981)),
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

  Widget _tag(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
