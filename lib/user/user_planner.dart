// lib/user/user_planner.dart
// Updated: removed top AppBar/title, removed "View Only" pill, removed Tasks/Meetings tab buttons.
// The 4 stat tiles are now at the very top of the page.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

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
  bool get isPast => dateTime != null && dateTime!.isBefore(DateTime.now());
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

class _UserPlannerPageState extends State<UserPlannerPage> {
  final List<Task> tasks = [];
  final List<Meeting> meetings = [];
  String currentTab = 'tasks'; // left as semantic but tabs removed
  String currentSubTab = 'all'; // For tasks: 'all', 'pending', 'completed', 'high'
  String search = '';
  late final DateFormat dateFormatter;

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _showMoreTasks = false;
  bool _showMoreMeetings = false;
  final int _maxVisibleItems = 10;

  static const Color segEmerald = Color(0xFF059669);
  static const Color emeraldStart = Color(0xFF10B981);
  static const Color accentPurple = Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    dateFormatter = DateFormat.yMMMEd();
    _loadData();
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // Load tasks
      final tasksData = await ApiService.getTasks();

      // Load meetings
      final meetingsData = await ApiService.getMeetings();

      if (!mounted) return;

      setState(() {
        // Process tasks
        tasks.clear();
        for (var item in tasksData) {
          tasks.add(Task.fromApi(item));
        }

        // Process meetings
        meetings.clear();
        for (var item in meetingsData) {
          meetings.add(Meeting.fromApi(item));
        }

        // Sort meetings by datetime
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
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
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

    // Sort by datetime (upcoming first)
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

  Widget _scaledText(BuildContext ctx, String txt, TextStyle? style, {int maxLines = 1}) {
    final double original = MediaQuery.of(ctx).textScaleFactor;
    final double capped = original.clamp(1.0, 1.25);
    return MediaQuery(
      data: MediaQuery.of(ctx).copyWith(textScaleFactor: capped),
      child: Text(
        txt,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: style,
      ),
    );
  }

  // -------------------------
  //   TASK CARD
  // -------------------------
  Widget _taskCard(Task t) {
    final diff = daysDiff(t.dueDateIso);
    final overdue = diff < 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EDF9),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _scaledText(
                    context,
                    t.title,
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    maxLines: 1,
                  ),
                ),
                if (t.completed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _scaledText(
                      context,
                      'Completed',
                      TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (t.desc.isNotEmpty)
              _scaledText(
                context,
                t.desc,
                TextStyle(fontSize: 13, color: Colors.grey.shade700),
                maxLines: 2,
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(t.type, Colors.white),
                _chip(t.priority, _priorityColor(t.priority)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: overdue ? Colors.red.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _scaledText(
                    context,
                    overdue ? '${diff.abs()}d overdue' : '$diff d left',
                    TextStyle(
                      color: overdue ? Colors.red.shade700 : Colors.grey.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------
  //   MEETING CARD
  // -------------------------
  Widget _meetingCard(Meeting m) {
    final isUpcoming = m.isUpcoming;
    final isPast = m.isPast;
    final isToday = m.dateTime != null &&
        m.dateTime!.year == DateTime.now().year &&
        m.dateTime!.month == DateTime.now().month &&
        m.dateTime!.day == DateTime.now().day;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _scaledText(
                    context,
                    m.title,
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    maxLines: 1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUpcoming ? Colors.blue.shade100 :
                           isToday ? Colors.orange.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _scaledText(
                    context,
                    isToday ? 'Today' :
                    isUpcoming ? 'Upcoming' : 'Past',
                    TextStyle(
                      color: isUpcoming ? Colors.blue.shade800 :
                             isToday ? Colors.orange.shade800 : Colors.grey.shade800,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
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
                  child: _scaledText(
                    context,
                    m.formattedDate,
                    TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            if (m.location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _scaledText(
                      context,
                      m.location,
                      TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ],
            if (m.purpose.isNotEmpty) ...[
              const SizedBox(height: 8),
              _scaledText(
                context,
                m.purpose,
                TextStyle(fontSize: 13, color: Colors.grey.shade700),
                maxLines: 2,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(m.type.isEmpty ? 'Meeting' : m.type, Colors.white),
                _chip(m.status, _statusColor(m.status)),
                if (m.attendees.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people, size: 12, color: Colors.purple.shade700),
                        const SizedBox(width: 4),
                        _scaledText(
                          context,
                          '${m.attendees.length} ${m.attendees.length == 1 ? 'person' : 'people'}',
                          TextStyle(
                            color: Colors.purple.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color bg) {
    final label = text.isNotEmpty
        ? (text[0].toUpperCase() + (text.length > 1 ? text.substring(1) : ''))
        : '';
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, maxWidth: 160),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: _scaledText(
            context,
            label,
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            maxLines: 1,
          ),
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
      case 'done':
        return Colors.green.shade100;
      case 'in progress':
        return Colors.blue.shade100;
      case 'cancelled':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Widget _taskSegmentedControl(List<String> tabs) {
    final mq = MediaQuery.of(context);
    final double baseFontSize = 13.0;
    final double fontSize = baseFontSize * (mq.size.width / 375).clamp(0.92, 1.05);

    return LayoutBuilder(builder: (ctx, constraints) {
      final int count = tabs.length;
      final double totalWidth = constraints.maxWidth;
      final double itemWidth = totalWidth / count;

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

            final double horizontalPadding = (10.0 * (mq.size.width / 375)).clamp(8.0, 14.0);
            final double verticalPadding = 6.0;
            final double pillHeight = (fontSize * 2.0).clamp(28.0, 40.0);
            final BorderRadius pillRadius = BorderRadius.circular(pillHeight / 2);

            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => currentSubTab = tab),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(
                      horizontal: active ? horizontalPadding : 8,
                      vertical: verticalPadding,
                    ),
                    decoration: active
                        ? BoxDecoration(
                            color: segEmerald,
                            borderRadius: pillRadius,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          )
                        : const BoxDecoration(color: Colors.transparent),
                    child: _scaledText(
                      context,
                      label,
                      TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    });
  }

  Widget _statTile(String label, int value, double height, Color color) {
    return Container(
      height: height,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: _scaledText(
              context,
              label,
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 18,
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

    final mq = MediaQuery.of(context);
    final double horizontalPad = (18.0 * (mq.size.width / 375)).clamp(12.0, 28.0);

    return Scaffold(
      // AppBar removed so top of screen is content (4 stat tiles will be at the very top)
      backgroundColor: const Color(0xFFF7FBF7),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            // top padding set to 0 so tiles are at the very top
            padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // --- TASKS STAT TILES (these are now at the very top of the page) ---
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final double screenW = constraints.maxWidth;
                    final double scale = (screenW / 375).clamp(0.85, 1.25);
                    final double tileHeight = (72.0 * scale).clamp(60.0, 110.0);

                    final bool singleRow = constraints.maxWidth >= 420;
                    if (singleRow) {
                      return Row(
                        children: [
                          Expanded(child: _statTile('Pending', taskStats['pending']!, tileHeight, Colors.blue.shade400)),
                          const SizedBox(width: 10),
                          Expanded(child: _statTile('Completed', taskStats['completed']!, tileHeight, Colors.green.shade400)),
                          const SizedBox(width: 10),
                          Expanded(child: _statTile('High', taskStats['high']!, tileHeight, Colors.red.shade400)),
                          const SizedBox(width: 10),
                          Expanded(child: _statTile('Overdue', taskStats['overdue']!, tileHeight, Colors.orange.shade400)),
                        ],
                      );
                    } else {
                      final double spacing = 10;
                      final double itemWidth = (constraints.maxWidth - spacing) / 2;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: 10,
                        children: [
                          SizedBox(width: itemWidth, child: _statTile('Pending', taskStats['pending']!, tileHeight, Colors.blue.shade400)),
                          SizedBox(width: itemWidth, child: _statTile('Completed', taskStats['completed']!, tileHeight, Colors.green.shade400)),
                          SizedBox(width: itemWidth, child: _statTile('High', taskStats['high']!, tileHeight, Colors.red.shade400)),
                          SizedBox(width: itemWidth, child: _statTile('Overdue', taskStats['overdue']!, tileHeight, Colors.orange.shade400)),
                        ],
                      );
                    }
                  },
                ),

                const SizedBox(height: 18),

                // -------------------------
                //  TASKS SECTION (kept content)
                // -------------------------
                _taskSegmentedControl(taskSubTabs),
                const SizedBox(height: 16),

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
                      child: Text(
                        'No tasks found',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  )
                else
                  ...visibleTasks.map(_taskCard).toList(),

                if (filteredTasks.length > _maxVisibleItems)
                  TextButton(
                    onPressed: () => setState(() => _showMoreTasks = !_showMoreTasks),
                    child: Text(
                      _showMoreTasks
                          ? 'Show less'
                          : 'Show more (${filteredTasks.length - _maxVisibleItems} more)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),

                const SizedBox(height: 28),

                // -------------------------
                //  MEETINGS SECTION
                // -------------------------
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentPurple.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: accentPurple),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _scaledText(
                          context,
                          'View your scheduled meetings. Only admins can create or modify meetings.',
                          TextStyle(color: accentPurple, fontSize: 13),
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final double screenW = constraints.maxWidth;
                    final double scale = (screenW / 375).clamp(0.85, 1.25);
                    final double tileHeight = (72.0 * scale).clamp(60.0, 110.0);

                    final bool singleRow = constraints.maxWidth >= 420;
                    if (singleRow) {
                      return Row(
                        children: [
                          Expanded(child: _statTile('Total', meetingStats['total']!, tileHeight, accentPurple)),
                          const SizedBox(width: 10),
                          Expanded(child: _statTile('Upcoming', meetingStats['upcoming']!, tileHeight, Colors.blue.shade400)),
                          const SizedBox(width: 10),
                          Expanded(child: _statTile('Today', meetingStats['today']!, tileHeight, Colors.orange.shade400)),
                          const SizedBox(width: 10),
                          Expanded(child: _statTile('Past', meetingStats['past']!, tileHeight, Colors.grey.shade400)),
                        ],
                      );
                    } else {
                      final double spacing = 10;
                      final double itemWidth = (constraints.maxWidth - spacing) / 2;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: 10,
                        children: [
                          SizedBox(width: itemWidth, child: _statTile('Total', meetingStats['total']!, tileHeight, accentPurple)),
                          SizedBox(width: itemWidth, child: _statTile('Upcoming', meetingStats['upcoming']!, tileHeight, Colors.blue.shade400)),
                          SizedBox(width: itemWidth, child: _statTile('Today', meetingStats['today']!, tileHeight, Colors.orange.shade400)),
                          SizedBox(width: itemWidth, child: _statTile('Past', meetingStats['past']!, tileHeight, Colors.grey.shade400)),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),

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
                      child: Text(
                        'No meetings found',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  )
                else
                  ...visibleMeetings.map(_meetingCard).toList(),

                if (filteredMeetings.length > _maxVisibleItems)
                  TextButton(
                    onPressed: () => setState(() => _showMoreMeetings = !_showMoreMeetings),
                    child: Text(
                      _showMoreMeetings
                          ? 'Show less'
                          : 'Show more (${filteredMeetings.length - _maxVisibleItems} more)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
