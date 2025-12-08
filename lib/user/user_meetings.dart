// lib/user/user_meetings.dart
// Read-only meetings view for regular users

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
      if (m['attendees'] is List) {
        attendeesList = List<String>.from(m['attendees']);
      } else if (m['attendees'] is String) {
        try {
          attendeesList = List<String>.from(m['attendees']);
        } catch (_) {}
      }
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
      final meetingsData = await ApiService.getMeetings();

      if (!mounted) return;

      setState(() {
        _meetings.clear();
        for (var item in meetingsData) {
          _meetings.add(Meeting.fromApi(item));
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Failed to load data: $e');
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final meetingsData = await ApiService.getMeetings();

      if (!mounted) return;

      setState(() {
        _meetings.clear();
        for (var item in meetingsData) {
          _meetings.add(Meeting.fromApi(item));
        }
        _isRefreshing = false;
      });

      _showSnack('Meetings refreshed');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRefreshing = false);
      _showSnack('Failed to refresh: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  List<Meeting> get filteredMeetings {
    if (_search.trim().isEmpty) return _meetings;
    final q = _search.toLowerCase();
    return _meetings.where((m) => m.title.toLowerCase().contains(q)).toList();
  }

  int get _upcoming7DaysCount {
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 7));
    return _meetings.where((m) => m.datetime.isAfter(now) && m.datetime.isBefore(cutoff)).length;
  }

  List<Meeting> get _nextUp {
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 7));
    final upcoming = _meetings.where((m) => m.datetime.isAfter(now) && m.datetime.isBefore(cutoff)).toList();
    upcoming.sort((a, b) => a.datetime.compareTo(b.datetime));
    return upcoming.take(3).toList();
  }

  void _openMeetingDetails(Meeting meeting) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        meeting.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _detailRow(Icons.access_time, 'Date & Time', _displayFormat.format(meeting.datetime)),
                const SizedBox(height: 12),
                _detailRow(Icons.category, 'Type', meeting.type),
                const SizedBox(height: 12),
                _detailRow(Icons.info_outline, 'Status', meeting.status),
                const SizedBox(height: 12),
                if (meeting.location != null && meeting.location!.isNotEmpty)
                  _detailRow(Icons.place, 'Location', meeting.location!),
                if (meeting.location != null && meeting.location!.isNotEmpty)
                  const SizedBox(height: 12),
                if (meeting.purpose != null && meeting.purpose!.isNotEmpty) ...[
                  const Text(
                    'Purpose',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    meeting.purpose!,
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                ],
                if (meeting.attendees.isNotEmpty) ...[
                  const Text(
                    'Attendees',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: meeting.attendees.map((attendee) {
                      return Chip(
                        label: Text(attendee),
                        backgroundColor: emeraldStart.withOpacity(0.1),
                        labelStyle: const TextStyle(fontSize: 12),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (meeting.isVirtual) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showSnack('Opening: ${meeting.meetLink}');
                      },
                      icon: const Icon(Icons.video_call),
                      label: const Text('Join Virtual Meeting'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: emeraldStart,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
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
        Icon(icon, size: 20, color: emeraldStart),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
      appBar: AppBar(
        title: const Text('My Meetings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: emeraldStart.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: emeraldStart.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.visibility, size: 16, color: emeraldStart),
                    SizedBox(width: 6),
                    Text(
                      'View Only',
                      style: TextStyle(
                        color: emeraldStart,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Next Up Hero
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [emeraldStart, emeraldEnd]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: emeraldEnd.withOpacity(0.18), blurRadius: 18, offset: const Offset(0, 8))],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.schedule, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Next Up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                            const SizedBox(height: 6),
                            if (_nextUp.isEmpty)
                              const Text('No upcoming meetings in next 7 days', style: TextStyle(color: Colors.white))
                            else
                              ..._nextUp.map((m) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(m.title, style: const TextStyle(color: Colors.white, fontSize: 13))),
                                        Text(DateFormat('MMM d').format(m.datetime), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                      ],
                                    ),
                                  )),
                          ],
                        ),
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [emeraldStart, emeraldEnd]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('$_upcoming7DaysCount', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                              const Text('upcoming', style: TextStyle(color: Colors.white70, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Info Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: emeraldStart.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: emeraldStart.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, color: emeraldStart),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This is a read-only view. Contact admin to schedule meetings.',
                          style: TextStyle(color: emeraldStart, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Search
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
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
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh),
                      onPressed: _isLoading ? null : _refreshData,
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Meetings list
                const Text('All Meetings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),

                if (_isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                else if (filtered.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No meetings found')))
                else
                  ...visible.map((m) => MeetingCard(
                        meeting: m,
                        dateFormat: _displayFormat,
                        onTap: () => _openMeetingDetails(m),
                      )),

                if (filtered.length > _maxVisibleMeetings)
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _showMoreMeetings = !_showMoreMeetings),
                      child: Text(_showMoreMeetings ? 'Show less' : 'Show more (${filtered.length - _maxVisibleMeetings} more)'),
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
    required this.meeting,
    required this.dateFormat,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tags = <Widget>[];
    if (meeting.type.isNotEmpty) {
      tags.add(_tag(context, meeting.type));
    }
    if (meeting.isVirtual) {
      tags.add(_tag(context, 'Virtual'));
    }

    final locationDisplay = (meeting.location ?? '').trim().isNotEmpty
        ? meeting.location!.trim()
        : (meeting.isVirtual ? 'Online' : '');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(meeting.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(meeting.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      meeting.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(meeting.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: tags),
              if (meeting.purpose != null && meeting.purpose!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(meeting.purpose!, style: TextStyle(color: Colors.grey.shade700), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      [dateFormat.format(meeting.datetime), if (locationDisplay.isNotEmpty) '•', if (locationDisplay.isNotEmpty) locationDisplay].join(' '),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
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
      child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}