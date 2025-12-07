// lib/admin/meetings.dart
// Complete Meetings page with Supabase integration

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

  Map<String, dynamic> toApi() {
    return {
      'title': title,
      'type': type,
      'purpose': purpose,
      'datetime': datetime.toIso8601String(),
      'location': location,
      'meetLink': meetLink,
      'status': status,
      'attendees': attendees,
    };
  }
}

class MeetingsPage extends StatefulWidget {
  const MeetingsPage({super.key});

  @override
  State<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends State<MeetingsPage> {
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _displayFormat = DateFormat('EEE, MMM d, h:mm a');

  final List<Meeting> _meetings = [];
  final List<String> _students = [];
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
      final studentsData = await ApiService.getStudents();

      if (!mounted) return;

      setState(() {
        _meetings.clear();
        for (var item in meetingsData) {
          _meetings.add(Meeting.fromApi(item));
        }

        _students.clear();
        for (var item in studentsData) {
          _students.add(item['name'] ?? '');
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

  Future<void> _createMeeting(Meeting meeting) async {
    try {
      final result = await ApiService.createMeeting(meeting.toApi());

      if (result['success'] == true) {
        await _loadData();
        _showSnack('Meeting created successfully');
      } else {
        _showSnack('Failed: ${result['message']}');
      }
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  Future<void> _updateMeeting(String meetingId, Map<String, dynamic> updates) async {
    try {
      final result = await ApiService.updateMeeting(int.parse(meetingId), updates);

      if (result['success'] == true) {
        await _loadData();
        _showSnack('Meeting updated');
      } else {
        _showSnack('Failed: ${result['message']}');
      }
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  Future<void> _deleteMeeting(String meetingId) async {
    try {
      final result = await ApiService.deleteMeeting(int.parse(meetingId));

      if (result['success'] == true) {
        await _loadData();
        _showSnack('Meeting deleted');
      } else {
        _showSnack('Failed: ${result['message']}');
      }
    } catch (e) {
      _showSnack('Error: $e');
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

  void _openAddEditSheet({Meeting? existing}) async {
    final result = await showModalBottomSheet<Meeting?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: AddEditMeetingSheet(
              students: _students,
              existing: existing,
            ),
          ),
        );
      },
    );

    if (result != null) {
      if (existing == null) {
        await _createMeeting(result);
      } else {
        await _updateMeeting(existing.id, result.toApi());
      }
    }
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete meeting?'),
        content: const Text('This will permanently remove the meeting.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteMeeting(id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _updateStatus(Meeting m, String newStatus) {
    _updateMeeting(m.id, {'status': newStatus});
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredMeetings;
    final visible = _showMoreMeetings ? filtered : filtered.take(_maxVisibleMeetings).toList();

    return Scaffold(
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

                // Search
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search meetings...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
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
                const Text('Meetings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),

                if (_isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                else if (filtered.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No meetings found')))
                else
                  ...visible.map((m) => MeetingCard(
                        meeting: m,
                        dateFormat: _displayFormat,
                        onEdit: () => _openAddEditSheet(existing: m),
                        onDelete: () => _confirmDelete(m.id),
                        onStatusChanged: (s) => _updateStatus(m, s),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEditSheet(),
        backgroundColor: emeraldStart,
        icon: const Icon(Icons.add),
        label: const Text('Add Meeting'),
      ),
    );
  }
}

class MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final DateFormat dateFormat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onStatusChanged;

  const MeetingCard({
    required this.meeting,
    required this.dateFormat,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
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
                IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: onEdit),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: onDelete),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: tags),
            if (meeting.purpose != null && meeting.purpose!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(meeting.purpose!, style: TextStyle(color: Colors.grey.shade700)),
            ],
            const SizedBox(height: 8),
            Text(
              [dateFormat.format(meeting.datetime), if (locationDisplay.isNotEmpty) '•', if (locationDisplay.isNotEmpty) locationDisplay].join(' '),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                DropdownButton<String>(
                  value: meeting.status,
                  items: ['Not Started', 'In Progress', 'Completed', 'Cancelled'].map((s) {
                    return DropdownMenuItem(value: s, child: Text(s));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) onStatusChanged(v);
                  },
                ),
                const Spacer(),
                if (meeting.isVirtual)
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Open ${meeting.meetLink}')));
                    },
                    child: const Text('Join'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
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

class AddEditMeetingSheet extends StatefulWidget {
  final Meeting? existing;
  final List<String> students;
  const AddEditMeetingSheet({required this.students, this.existing, super.key});

  @override
  State<AddEditMeetingSheet> createState() => _AddEditMeetingSheetState();
}

class _AddEditMeetingSheetState extends State<AddEditMeetingSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _purposeController;
  late TextEditingController _locationController;
  late TextEditingController _meetLinkController;
  String _type = 'project';
  DateTime? _datetime;
  bool _isVirtual = false;
  Set<String> _selectedStudents = {};

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleController = TextEditingController(text: e?.title ?? '');
    _purposeController = TextEditingController(text: e?.purpose ?? '');
    _locationController = TextEditingController(text: e?.location ?? '');
    _meetLinkController = TextEditingController(text: e?.meetLink ?? '');
    _type = e?.type ?? 'project';
    _datetime = e?.datetime;
    _isVirtual = e?.isVirtual ?? false;
    _selectedStudents = e != null ? Set.from(e.attendees) : {};
  }

  @override
  void dispose() {
    _titleController.dispose();
    _purposeController.dispose();
    _locationController.dispose();
    _meetLinkController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _datetime ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_datetime ?? now));
    if (time == null) return;
    setState(() {
      _datetime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_datetime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick date & time')));
      return;
    }

    final id = widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final meeting = Meeting(
      id: id,
      title: _titleController.text.trim(),
      type: _type,
      purpose: _purposeController.text.trim(),
      datetime: _datetime!,
      location: _locationController.text.trim(),
      meetLink: _isVirtual ? _meetLinkController.text.trim() : null,
      attendees: _selectedStudents.toList(),
    );

    Navigator.of(context).pop(meeting);
  }

  @override
  Widget build(BuildContext context) {
    final display = _datetime == null ? 'Pick date & time' : DateFormat('EEE, MMM d • h:mm a').format(_datetime!);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(widget.existing == null ? 'Add Meeting' : 'Edit Meeting', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _type,
                      items: const [
                        DropdownMenuItem(value: 'project', child: Text('Project')),
                        DropdownMenuItem(value: 'office hours', child: Text('Office Hours')),
                        DropdownMenuItem(value: 'advising', child: Text('Advising')),
                        DropdownMenuItem(value: 'study group', child: Text('Study Group')),
                      ],
                      onChanged: (v) => setState(() => _type = v ?? 'project'),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(onPressed: _pickDateTime, child: Text(display)),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _purposeController, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Purpose', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextFormField(controller: _locationController, decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(value: _isVirtual, onChanged: (v) => setState(() => _isVirtual = v ?? false)),
                  const Text('Virtual'),
                ],
              ),
              if (_isVirtual) ...[
                const SizedBox(height: 8),
                TextFormField(controller: _meetLinkController, decoration: const InputDecoration(labelText: 'Meet link', border: OutlineInputBorder())),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(onPressed: _save, child: Text(widget.existing == null ? 'Add' : 'Save'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}