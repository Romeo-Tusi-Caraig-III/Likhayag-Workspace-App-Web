// lib/user/user_planner.dart
// Enhanced version with admin design but view-only for users
// Emerald gradient theme, improved UX, displays tasks and meetings in unified view

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

// Global emerald gradient colors
const Color themeStart = Color(0xFF10B981); // emerald-500
const Color themeEnd = Color(0xFF059669); // emerald-600
const Color accentPurple = Color(0xFF7C3AED);

class Task {
  String id;
  String title;
  String desc;
  String type;
  String priority;
  String dueDateIso;
  bool completed;

  Task({
    required this.id,
    required this.title,
    this.desc = '',
    this.type = 'assignment',
    this.priority = 'medium',
    required this.dueDateIso,
    this.completed = false,
  });

  factory Task.fromApi(Map<String, dynamic> m) {
    return Task(
      id: m['id'].toString(),
      title: (m['title'] ?? '').toString(),
      desc: (m['notes'] ?? '').toString(),
      type: (m['type'] ?? 'assignment').toString(),
      priority: (m['priority'] ?? 'medium').toString(),
      dueDateIso: (m['due'] ?? '').toString(),
      completed: m['completed'] == true,
    );
  }
}

class Meeting {
  String id;
  String title;
  String type;
  String purpose;
  String datetime;
  String location;
  String meetLink;
  String status;
  List<dynamic> attendees;

  Meeting({
    required this.id,
    required this.title,
    this.type = '',
    this.purpose = '',
    required this.datetime,
    this.location = '',
    this.meetLink = '',
    this.status = 'Not Started',
    this.attendees = const [],
  });

  factory Meeting.fromApi(Map<String, dynamic> m) {
    return Meeting(
      id: m['id'].toString(),
      title: m['title']?.toString() ?? 'Untitled Meeting',
      type: m['type']?.toString() ?? '',
      purpose: m['purpose']?.toString() ?? '',
      datetime: m['datetime']?.toString() ?? '',
      location: m['location']?.toString() ?? '',
      meetLink: m['meetLink']?.toString() ?? m['meet_link']?.toString() ?? '',
      status: m['status']?.toString() ?? 'Not Started',
      attendees: m['attendees'] is List ? m['attendees'] : [],
    );
  }

  DateTime? get dateTime => DateTime.tryParse(datetime);
  bool get isUpcoming => dateTime != null && dateTime!.isAfter(DateTime.now());
  String get formattedDate {
    if (datetime.isEmpty) return 'No date';
    final d = DateTime.tryParse(datetime);
    if (d == null) return 'Invalid date';
    return DateFormat.yMMMd().add_jm().format(d);
  }
}

class UserPlannerPage extends StatefulWidget {
  const UserPlannerPage({super.key});

  @override
  State<UserPlannerPage> createState() => _UserPlannerPageState();
}

class _UserPlannerPageState extends State<UserPlannerPage> with SingleTickerProviderStateMixin {
  final List<Task> tasks = [];
  final List<Meeting> meetings = [];
  String currentTab = 'tasks';
  String currentSubTab = 'all';
  String search = '';
  late final DateFormat dateFormatter;

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _showMoreTasks = false;
  bool _showMoreMeetings = false;
  final int _maxVisibleItems = 8;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    dateFormatter = DateFormat.yMMMEd();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          currentTab = _tabController.index == 0 ? 'tasks' : 'meetings';
        });
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final tasksData = await ApiService.getTasks();
      final meetingsData = await ApiService.getMeetings();

      if (!mounted) return;

      setState(() {
        tasks.clear();
        for (var item in tasksData) {
          tasks.add(Task.fromApi(item));
        }

        meetings.clear();
        for (var item in meetingsData) {
          meetings.add(Meeting.fromApi(item));
        }

        meetings.sort((a, b) {
          final da = a.dateTime;
          final db = b.dateTime;
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });

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
      final tasksData = await ApiService.getTasks();
      final meetingsData = await ApiService.getMeetings();

      if (!mounted) return;

      setState(() {
        tasks.clear();
        for (var item in tasksData) {
          tasks.add(Task.fromApi(item));
        }

        meetings.clear();
        for (var item in meetingsData) {
          meetings.add(Meeting.fromApi(item));
        }

        _isRefreshing = false;
      });
      _showSnack('Data refreshed');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRefreshing = false);
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

  int daysDiff(String? iso) {
    if (iso == null || iso.isEmpty) return 9999;
    DateTime? d = DateTime.tryParse(iso);
    if (d == null) return 9999;
    final today = DateTime.now();
    final td = DateTime(today.year, today.month, today.day);
    final target = DateTime(d.year, d.month, d.day);
    return target.difference(td).inDays;
  }

  String fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return 'TBD';
    return dateFormatter.format(d);
  }

  List<Task> getFilteredSortedTasks() {
    final q = search.trim().toLowerCase();

    var list = tasks.where((t) {
      final matches = q.isEmpty ||
          t.title.toLowerCase().contains(q) ||
          t.desc.toLowerCase().contains(q);

      if (!matches) return false;

      if (currentSubTab == 'pending') return !t.completed;
      if (currentSubTab == 'completed') return t.completed;
      if (currentSubTab == 'high') return t.priority == 'high';
      return true;
    }).toList();

    list.sort((a, b) {
      final da = DateTime.tryParse(a.dueDateIso);
      final db = DateTime.tryParse(b.dueDateIso);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });

    return list;
  }

  List<Meeting> getFilteredSortedMeetings() {
    final q = search.trim().toLowerCase();

    var list = meetings.where((m) {
      final matches = q.isEmpty ||
          m.title.toLowerCase().contains(q) ||
          m.purpose.toLowerCase().contains(q) ||
          m.location.toLowerCase().contains(q);
      return matches;
    }).toList();

    list.sort((a, b) {
      final da = a.dateTime;
      final db = b.dateTime;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });

    return list;
  }

  Map<String, int> computeTaskStats() {
    return {
      'pending': tasks.where((t) => !t.completed).length,
      'completed': tasks.where((t) => t.completed).length,
      'high': tasks.where((t) => t.priority == 'high').length,
      'overdue': tasks.where((t) => daysDiff(t.dueDateIso) < 0 && !t.completed).length,
    };
  }

  Map<String, int> computeMeetingStats() {
    final now = DateTime.now();
    final upcoming = meetings.where((m) {
      final dt = m.dateTime;
      return dt != null && dt.isAfter(now);
    }).length;

    final past = meetings.where((m) {
      final dt = m.dateTime;
      return dt != null && dt.isBefore(now);
    }).length;

    return {
      'upcoming': upcoming,
      'past': past,
      'total': meetings.length,
      'today': meetings.where((m) {
        final dt = m.dateTime;
        if (dt == null) return false;
        return dt.year == now.year && dt.month == now.month && dt.day == now.day;
      }).length,
    };
  }

  Widget _taskCard(Task t) {
    final diff = daysDiff(t.dueDateIso);
    final overdue = diff < 0;

    return Card(
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
                Expanded(
                  child: Text(
                    t.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                if (t.completed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 12, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Completed',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (t.desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                t.desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(t.type, const Color(0xFFF0FDF4)),
                _chip(t.priority, _priorityColor(t.priority)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: overdue ? Colors.red.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    overdue ? '${diff.abs()}d overdue' : '$diff d left',
                    style: TextStyle(
                      color: overdue ? Colors.red.shade700 : Colors.grey.shade800,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _meetingCard(Meeting m) {
    final isUpcoming = m.isUpcoming;
    final isToday = m.dateTime != null &&
        m.dateTime!.year == DateTime.now().year &&
        m.dateTime!.month == DateTime.now().month &&
        m.dateTime!.day == DateTime.now().day;

    return Card(
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
                Expanded(
                  child: Text(
                    m.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor(m.status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _statusIcon(m.status),
                        size: 12,
                        color: _statusColor(m.status),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        m.status,
                        style: TextStyle(
                          color: _statusColor(m.status),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    m.formattedDate,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            if (m.location.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      m.location,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ],
            if (m.purpose.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                m.purpose,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (m.type.isNotEmpty) _chip(m.type, const Color(0xFFF0FDF4)),
                if (isToday)
                  _chip('Today', Colors.orange.shade100)
                else if (isUpcoming)
                  _chip('Upcoming', Colors.blue.shade100),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
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

  Color _priorityColor(String p) {
    if (p == 'high') return Colors.red.shade100;
    if (p == 'low') return Colors.green.shade100;
    return Colors.orange.shade100;
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

  Widget _taskSegmentedControl(List<String> tabs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: tabs.map((tab) {
          final bool active = currentSubTab == tab;
          final String label = tab[0].toUpperCase() + tab.substring(1);

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => currentSubTab = tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: active
                    ? BoxDecoration(
                        color: themeEnd,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      )
                    : const BoxDecoration(color: Colors.transparent),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _statTile(String label, int value, Color color) {
    return Container(
      height: 82,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = getFilteredSortedTasks();
    final filteredMeetings = getFilteredSortedMeetings();
    final taskStats = computeTaskStats();
    final meetingStats = computeMeetingStats();

    final visibleTasks = _showMoreTasks ? filteredTasks : filteredTasks.take(_maxVisibleItems).toList();
    final visibleMeetings = _showMoreMeetings ? filteredMeetings : filteredMeetings.take(_maxVisibleItems).toList();

    final taskSubTabs = ['all', 'pending', 'completed', 'high'];

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF7),
      appBar: AppBar(
        title: const Text('Planner', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: (_isLoading || _isRefreshing) ? null : _refreshData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: themeEnd,
              unselectedLabelColor: Colors.grey,
              indicatorColor: themeEnd,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Tasks'),
                Tab(text: 'Meetings'),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: TabBarView(
            controller: _tabController,
            children: [
              // TASKS TAB
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Task stats
                    Row(
                      children: [
                        Expanded(child: _statTile('Pending', taskStats['pending']!, Colors.blue.shade400)),
                        const SizedBox(width: 10),
                        Expanded(child: _statTile('Done', taskStats['completed']!, Colors.green.shade400)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _statTile('High', taskStats['high']!, Colors.red.shade400)),
                        const SizedBox(width: 10),
                        Expanded(child: _statTile('Overdue', taskStats['overdue']!, Colors.orange.shade400)),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Filter tabs
                    _taskSegmentedControl(taskSubTabs),
                    const SizedBox(height: 16),

                    // Search
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search tasks...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) => setState(() => search = v),
                    ),
                    const SizedBox(height: 16),

                    // View-only info banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: themeStart.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: themeStart.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: themeStart, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'View-only mode. Contact admin to modify tasks.',
                              style: TextStyle(color: themeStart, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tasks list
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (filteredTasks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.inbox, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'No tasks found',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...visibleTasks.map(_taskCard).toList(),

                    if (filteredTasks.length > _maxVisibleItems)
                      Center(
                        child: TextButton(
                          onPressed: () => setState(() => _showMoreTasks = !_showMoreTasks),
                          child: Text(
                            _showMoreTasks
                                ? 'Show less'
                                : 'Show more (${filteredTasks.length - _maxVisibleItems} more)',
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // MEETINGS TAB
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meeting stats
                    Row(
                      children: [
                        Expanded(child: _statTile('Total', meetingStats['total']!, accentPurple)),
                        const SizedBox(width: 10),
                        Expanded(child: _statTile('Upcoming', meetingStats['upcoming']!, Colors.blue.shade400)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _statTile('Today', meetingStats['today']!, Colors.orange.shade400)),
                        const SizedBox(width: 10),
                        Expanded(child: _statTile('Past', meetingStats['past']!, Colors.grey.shade400)),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Search
                    TextField(
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
                      onChanged: (v) => setState(() => search = v),
                    ),
                    const SizedBox(height: 16),

                    // View-only info banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accentPurple.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: accentPurple, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'View your scheduled meetings. Only admins can modify meetings.',
                              style: TextStyle(color: accentPurple, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Meetings list
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (filteredMeetings.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.event_busy, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'No meetings found',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...visibleMeetings.map(_meetingCard).toList(),

                    if (filteredMeetings.length > _maxVisibleItems)
                      Center(
                        child: TextButton(
                          onPressed: () => setState(() => _showMoreMeetings = !_showMoreMeetings),
                          child: Text(
                            _showMoreMeetings
                                ? 'Show less'
                                : 'Show more (${filteredMeetings.length - _maxVisibleItems} more)',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}