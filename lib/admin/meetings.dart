// lib/admin/meetings.dart
// Enhanced Meetings with url_launcher, swipe-to-delete, multi-select, and visual tweaks

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
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
    // Safe attendees parsing
    List<String> attendeesList = [];
    final attendeesRaw = m['attendees'];
    if (attendeesRaw is List) {
      attendeesList = attendeesRaw.map((e) => (e?.toString() ?? '')).where((s) => s.isNotEmpty).toList();
    }

    // Safe datetime parsing with fallback
    DateTime parsedDate;
    final dtRaw = m['datetime'];
    if (dtRaw != null) {
      try {
        parsedDate = DateTime.parse(dtRaw.toString());
      } catch (_) {
        parsedDate = DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }

    // Location and meet link with tolerant keys
    String? location;
    if (m.containsKey('location') && m['location'] != null) {
      location = m['location'].toString();
    } else if (m.containsKey('Location') && m['Location'] != null) {
      location = m['Location'].toString();
    }

    String? meetLink;
    if (m.containsKey('meetLink') && m['meetLink'] != null) {
      meetLink = m['meetLink'].toString();
    } else if (m.containsKey('meet_link') && m['meet_link'] != null) {
      meetLink = m['meet_link'].toString();
    }

    return Meeting(
      id: m['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: (m['title'] ?? '').toString(),
      type: (m['type'] ?? 'project').toString(),
      purpose: m['purpose']?.toString(),
      datetime: parsedDate,
      location: location,
      meetLink: meetLink,
      status: (m['status'] ?? 'Not Started').toString(),
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

class _MeetingsPageState extends State<MeetingsPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _displayFormat = DateFormat('EEE, MMM d, h:mm a');

  final List<Meeting> _meetings = [];
  final List<String> _students = [];
  String _search = '';
  bool _isLoading = false;
  bool _isRefreshing = false;

  final int _maxVisibleMeetings = 6;
  bool _showMoreMeetings = false;

  bool _fabExpanded = false;
  late AnimationController _fabController;

  // New color theme (deep purple)
  static const Color themeStart = Color(0xFF6D28D9);
  static const Color themeEnd = Color(0xFF4C1D95);

  // Selection state for multi-select
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();

    _fabController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _searchController.addListener(() {
      if (mounted) setState(() {}); // for clear button visibility
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final meetingsData = await ApiService.getMeetings();
      final studentsData = await ApiService.getStudents();

      if (!mounted) return;

      setState(() {
        _meetings.clear();
        for (var item in meetingsData) {
          if (item is Map<String, dynamic>) {
            _meetings.add(Meeting.fromApi(item));
          } else if (item is Map) {
            _meetings.add(Meeting.fromApi(Map<String, dynamic>.from(item)));
          }
        }

        _students.clear();
        for (var item in studentsData) {
          if (item is Map && item.containsKey('name')) {
            _students.add((item['name'] ?? '').toString());
          } else {
            _students.add(item.toString());
          }
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
    if (_isRefreshing || _isLoading) return;
    setState(() => _isRefreshing = true);

    try {
      final meetingsData = await ApiService.getMeetings();

      if (!mounted) return;

      setState(() {
        _meetings.clear();
        for (var item in meetingsData) {
          if (item is Map<String, dynamic>) {
            _meetings.add(Meeting.fromApi(item));
          } else if (item is Map) {
            _meetings.add(Meeting.fromApi(Map<String, dynamic>.from(item)));
          }
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

      if (result != null && result['success'] == true) {
        await _loadData();
        _showSnack('Meeting created successfully');
      } else {
        _showSnack('Failed: ${result?['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  Future<void> _updateMeeting(String meetingId, Map<String, dynamic> updates) async {
    try {
      final result = await ApiService.updateMeeting(meetingId, updates);

      if (result != null && result['success'] == true) {
        await _loadData();
        _showSnack('Meeting updated');
      } else {
        _showSnack('Failed: ${result?['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  Future<void> _deleteMeeting(String meetingId) async {
    try {
      final result = await ApiService.deleteMeeting(meetingId);

      if (result != null && result['success'] == true) {
        await _loadData();
        _selectedIds.remove(meetingId);
        _showSnack('Meeting deleted');
      } else {
        _showSnack('Failed: ${result?['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  Future<void> _bulkDeleteSelected() async {
    if (_selectedIds.isEmpty) {
      _showSnack('No meetings selected');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_selectedIds.length} meeting(s)?'),
        content: const Text('This will permanently delete the selected meetings.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: themeStart),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    int deleted = 0;
    for (var id in _selectedIds.toList()) {
      try {
        final res = await ApiService.deleteMeeting(id);
        if (res != null && res['success'] == true) {
          deleted++;
          _selectedIds.remove(id);
        }
      } catch (e) {
        // continue
      }
    }

    await _loadData();
    _showSnack('Deleted $deleted meeting(s)');
  }

  Future<void> _bulkUpdateStatus(String status) async {
    if (_selectedIds.isEmpty) {
      _showSnack('No meetings selected');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update ${_selectedIds.length} meeting(s) to "$status"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: themeStart),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    int updated = 0;
    for (var id in _selectedIds.toList()) {
      try {
        final res = await ApiService.updateMeeting(id, {'status': status});
        if (res != null && res['success'] == true) {
          updated++;
        }
      } catch (e) {
        // continue
      }
    }

    await _loadData();
    _selectedIds.clear();
    _showSnack('Updated $updated meeting(s)');
  }

  Future<bool?> _confirmDismiss(BuildContext context, Meeting meeting) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete meeting?'),
        content: Text('Delete "${meeting.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Confirm deletion of a single meeting (used by the delete icon in MeetingCard)
  Future<void> _confirmDelete(String meetingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete meeting?'),
        content: const Text('This will permanently delete the meeting. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteMeeting(meetingId);
    }
  }

  Future<void> _exportMeetings() async {
    _showSnack('Exporting meetings... (Feature coming soon)');
    // TODO: Implement export to CSV/PDF
  }

  void _toggleFAB() {
    setState(() {
      _fabExpanded = !_fabExpanded;
      if (_fabExpanded) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
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
    if (_search.trim().isEmpty) return _meetings;
    final q = _search.toLowerCase();
    return _meetings.where((m) {
      return m.title.toLowerCase().contains(q) ||
          (m.purpose ?? '').toLowerCase().contains(q) ||
          (m.location ?? '').toLowerCase().contains(q);
    }).toList();
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) _selectedIds.remove(id);
      else _selectedIds.add(id);
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  void _updateStatus(Meeting m, String newStatus) {
    _updateMeeting(m.id, {'status': newStatus});
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredMeetings;
    final visible = _showMoreMeetings ? filtered : filtered.take(_maxVisibleMeetings).toList();

    return Scaffold(
      // When selection active show selection bar at top
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with stats
                    _buildHeaderCard(),
                    const SizedBox(height: 18),

                    // Search bar
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search meetings or purpose...',
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
                              fillColor: Colors.grey.shade100,
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
                          tooltip: 'Refresh',
                          onPressed: (_isLoading || _isRefreshing) ? null : _refreshData,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Meetings list
                    const Text('Meetings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),

                    if (_isLoading)
                      _buildShimmerPlaceholders()
                    else if (filtered.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const Icon(Icons.event_busy, size: 48, color: Colors.grey),
                              const SizedBox(height: 8),
                              const Text('No meetings found', style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _openAddEditSheet,
                                icon: const Icon(Icons.add),
                                label: const Text('Add your first meeting'),
                                style: ElevatedButton.styleFrom(backgroundColor: themeStart),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: visible.map((m) {
                          return Dismissible(
                            key: Key('meeting_${m.id}'),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) async => (await _confirmDismiss(context, m)) ?? false,
                            onDismissed: (_) async {
                              await _deleteMeeting(m.id);
                            },
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.delete_forever, color: Colors.white),
                            ),
                            child: MeetingCard(
                              meeting: m,
                              dateFormat: _displayFormat,
                              onEdit: () => _openAddEditSheet(existing: m),
                              onDelete: () => _confirmDelete(m.id),
                              onStatusChanged: (s) => _updateStatus(m, s),
                              onToggleSelect: () => _toggleSelect(m.id),
                              isSelected: _selectedIds.contains(m.id),
                            ),
                          );
                        }).toList(),
                      ),

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

          // Selection bar
          if (_selectedIds.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                child: Material(
                  elevation: 6,
                  color: themeStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: _clearSelection,
                          tooltip: 'Clear selection',
                        ),
                        Expanded(
                          child: Text(
                            '${_selectedIds.length} selected',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          onPressed: _bulkDeleteSelected,
                          tooltip: 'Delete selected',
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) => _bulkUpdateStatus(v),
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(value: 'Not Started', child: Text('Mark Not Started')),
                            PopupMenuItem(value: 'In Progress', child: Text('Mark In Progress')),
                            PopupMenuItem(value: 'Completed', child: Text('Mark Completed')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Overlay when FAB is expanded
          if (_fabExpanded)
            GestureDetector(
              onTap: _toggleFAB,
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildSmartFAB(),
    );
  }

  Widget _buildShimmerPlaceholders() {
    // shimmer depends on the 'shimmer' package
    return Column(
      children: List.generate(4, (i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(14),
            ),
          ),
        );
      }),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Next Up',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
          ),
          const SizedBox(height: 12),
          if (_nextUp.isEmpty)
            const Text(
              'No upcoming meetings in next 7 days',
              style: TextStyle(color: Colors.white70),
            )
          else
            ..._nextUp.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          m.title,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          DateFormat('MMM d, h:mm a').format(m.datetime),
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                )),
          const SizedBox(height: 8),
          Row(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_available, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '$_upcoming7DaysCount upcoming',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmartFAB() {
    // Use smaller FABs and smaller icons
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Export button
        AnimatedOpacity(
          opacity: _fabExpanded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: _fabExpanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SmallFAB(
                    onPressed: () {
                      _toggleFAB();
                      _exportMeetings();
                    },
                    icon: Icons.download,
                    label: 'Export',
                    heroTag: 'export',
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // Bulk update button
        AnimatedOpacity(
          opacity: _fabExpanded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: _fabExpanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SmallFAB(
                    onPressed: () {
                      _toggleFAB();
                      // if selection exists, show actions; else open bulk dialog
                      if (_selectedIds.isNotEmpty) {
                        // open popup to choose status
                        showMenu(
                          context: context,
                          position: const RelativeRect.fromLTRB(1000, 80, 8, 0),
                          items: [
                            PopupMenuItem(value: 'In Progress', child: const Text('Mark as In Progress')),
                            PopupMenuItem(value: 'Completed', child: const Text('Mark as Completed')),
                          ],
                        ).then((v) {
                          if (v != null) _bulkUpdateStatus(v);
                        });
                      } else {
                        _showBulkUpdateDialog();
                      }
                    },
                    icon: Icons.checklist,
                    label: 'Bulk',
                    heroTag: 'bulk',
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // Main FAB (small)
        FloatingActionButton.small(
          onPressed: _fabExpanded ? _toggleFAB : () => _openAddEditSheet(),
          backgroundColor: themeStart,
          heroTag: 'main',
          tooltip: _fabExpanded ? 'Close' : 'Add meeting',
          child: AnimatedRotation(
            turns: _fabExpanded ? 0.125 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(_fabExpanded ? Icons.close : Icons.add, size: 20),
          ),
        ),
      ],
    );
  }

  void _showBulkUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Bulk Update Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Mark as In Progress'),
              onTap: () {
                Navigator.pop(context);
                _bulkUpdateStatus('In Progress');
              },
            ),
            ListTile(
              title: const Text('Mark as Completed'),
              onTap: () {
                Navigator.pop(context);
                _bulkUpdateStatus('Completed');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallFAB extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final String heroTag;

  const _SmallFAB({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      heroTag: heroTag,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF4C1D95),
      elevation: 3,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

// MeetingCard and AddEditMeetingSheet implementations

class MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final DateFormat dateFormat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onToggleSelect;
  final bool isSelected;

  const MeetingCard({
    required this.meeting,
    required this.dateFormat,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
    required this.onToggleSelect,
    required this.isSelected,
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

    return GestureDetector(
      onLongPress: onToggleSelect,
      child: Card(
        color: isSelected ? Colors.grey.shade200 : null,
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isSelected) ...[
                    const Icon(Icons.check_circle, color: Colors.deepPurple, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(meeting.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: onEdit, tooltip: 'Edit'),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: onDelete, tooltip: 'Delete'),
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
                locationDisplay.isNotEmpty
                    ? '${dateFormat.format(meeting.datetime)} • $locationDisplay'
                    : dateFormat.format(meeting.datetime),
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
                    ElevatedButton.icon(
                      onPressed: () async {
                        final link = meeting.meetLink;
                        if (link == null || link.trim().isEmpty) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No meeting link available')));
                          }
                          return;
                        }
                        final uri = Uri.tryParse(link);
                        if (uri == null) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid URL')));
                          return;
                        }
                        try {
                          if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link')));
                          }
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error opening link: $e')));
                        }
                      },
                      icon: const Icon(Icons.video_call, size: 16),
                      label: const Text('Join'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D28D9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF6D28D9).withOpacity(0.12)),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFF4C1D95), fontSize: 11, fontWeight: FontWeight.w600)),
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
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_datetime ?? now),
    );
    if (time == null || !mounted) return;

    setState(() {
      _datetime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_datetime == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick date & time')),
        );
      }
      return;
    }

    final id = widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final meeting = Meeting(
      id: id,
      title: _titleController.text.trim(),
      type: _type,
      purpose: _purposeController.text.trim(),
      datetime: _datetime!,
      location: (_locationController.text.trim().isEmpty) ? null : _locationController.text.trim(),
      meetLink: _isVirtual ? _meetLinkController.text.trim() : null,
      attendees: _selectedStudents.toList(),
    );

    Navigator.of(context).pop(meeting);
  }

  @override
  Widget build(BuildContext context) {
    final display = _datetime == null ? 'Pick date & time' : DateFormat('EEE, MMM d • h:mm a').format(_datetime!);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(widget.existing == null ? 'Add Meeting' : 'Edit Meeting',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _type,
                      decoration: InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'project', child: Text('Project')),
                        DropdownMenuItem(value: 'office hours', child: Text('Office Hours')),
                        DropdownMenuItem(value: 'advising', child: Text('Advising')),
                        DropdownMenuItem(value: 'study group', child: Text('Study Group')),
                      ],
                      onChanged: (v) => setState(() => _type = v ?? 'project'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _pickDateTime,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(display),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _purposeController,
                decoration: InputDecoration(
                  labelText: 'Purpose (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Location (leave empty if virtual)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Virtual meeting?'),
                  const SizedBox(width: 12),
                  Switch(
                    value: _isVirtual,
                    onChanged: (v) => setState(() {
                      _isVirtual = v;
                      if (!v) _meetLinkController.clear();
                    }),
                  ),
                  const Spacer(),
                  Text('${_selectedStudents.length} attendee(s)'),
                ],
              ),
              if (_isVirtual) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _meetLinkController,
                  decoration: InputDecoration(
                    labelText: 'Meeting link',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  validator: (v) {
                    if (_isVirtual && (v == null || v.trim().isEmpty)) return 'Link required for virtual meetings';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              const Text('Attendees (tap to toggle)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.students.map((s) {
                  final selected = _selectedStudents.contains(s);
                  return ChoiceChip(
                    label: Text(s),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _selectedStudents.add(s);
                        } else {
                          _selectedStudents.remove(s);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D28D9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
