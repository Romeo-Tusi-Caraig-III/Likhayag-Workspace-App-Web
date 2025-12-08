// lib/user/user_planner.dart
// Same as before but with smaller, fixed-looking pill + chip text sizes
// Pills remain shrink-wrapped & circular-like, stable under scaling.

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

class UserPlannerPage extends StatefulWidget {
  const UserPlannerPage({super.key});

  @override
  State<UserPlannerPage> createState() => _UserPlannerPageState();
}

class _UserPlannerPageState extends State<UserPlannerPage> {
  final List<Task> tasks = [];
  String currentTab = 'all';
  String search = '';
  late final DateFormat dateFormatter;

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _showMoreTasks = false;
  final int _maxVisibleTasks = 10;

  static const Color segEmerald = Color(0xFF059669);
  static const Color emeraldStart = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    dateFormatter = DateFormat.yMMMEd();
    _loadTasksFromApi();
  }

  Future<void> _loadTasksFromApi() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final data = await ApiService.getTasks();
      if (!mounted) return;

      setState(() {
        tasks.clear();
        for (var item in data) {
          tasks.add(Task.fromApi(item));
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Failed to load tasks: $e');
    }
  }

  Future<void> _refreshTasks() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final data = await ApiService.getTasks();
      if (!mounted) return;

      setState(() {
        tasks.clear();
        for (var item in data) {
          tasks.add(Task.fromApi(item));
        }
        _isRefreshing = false;
      });
      _showSnack('Tasks refreshed');
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

  List<Task> getFilteredSorted() {
    final q = search.trim().toLowerCase();

    var list = tasks.where((t) {
      final matches = q.isEmpty ||
          t.title.toLowerCase().contains(q) ||
          t.desc.toLowerCase().contains(q);

      if (!matches) return false;

      if (currentTab == 'pending') return !t.completed;
      if (currentTab == 'completed') return t.completed;
      if (currentTab == 'high') return t.priority == 'high';
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

  Map<String, int> computeStats() {
    return {
      'pending': tasks.where((t) => !t.completed).length,
      'completed': tasks.where((t) => t.completed).length,
      'high': tasks.where((t) => t.priority == 'high').length,
      'overdue': tasks.where((t) => daysDiff(t.dueDateIso) < 0 && !t.completed).length,
    };
  }

  // Helper: render text with a capped textScaleFactor for critical UI pieces.
  // We clamp system scaling to help avoid mid-word wrapping while staying accessible.
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
  //   PRETTY TASK CARD
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
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _scaledText(context, t.title,
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                maxLines: 1),
            const SizedBox(height: 6),
            if (t.desc.isNotEmpty)
              _scaledText(context, t.desc, const TextStyle(fontSize: 13), maxLines: 2),
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
                          fontSize: 12),
                      maxLines: 1),
                ),
                _chip(
                  t.completed ? 'Completed' : 'Pending',
                  t.completed ? Colors.green.shade100 : Colors.amber.shade100,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Strict chip: smaller text now, fixed min width to keep stable appearance
  Widget _chip(String text, Color bg) {
    final label = text.isNotEmpty
        ? (text[0].toUpperCase() + (text.length > 1 ? text.substring(1) : ''))
        : '';
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, maxWidth: 160),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
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

  // -------------------------
  //   Segmented control widget
  // -------------------------
  Widget _segmentedControl(List<String> tabs) {
    // Reduce pill font size slightly and keep pill padding fixed so the pill
    // remains circular/rounded and predictable.
    final mq = MediaQuery.of(context);
    final double baseFontSize = 13.0; // reduced from 14
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
            final bool active = currentTab == tab;
            final String label = tab[0].toUpperCase() + tab.substring(1);

            // Smaller, fixed-looking pill padding
            final double horizontalPadding = (10.0 * (mq.size.width / 375)).clamp(8.0, 14.0);
            final double verticalPadding = 6.0;
            final double pillHeight = (fontSize * 2.0).clamp(28.0, 40.0);
            final BorderRadius pillRadius = BorderRadius.circular(pillHeight / 2);

            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => currentTab = tab),
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
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1))
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

  // -------------------------
  //   UI BUILD
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final filtered = getFilteredSorted();
    final stats = computeStats();
    final visible = _showMoreTasks ? filtered : filtered.take(_maxVisibleTasks).toList();

    final tabs = ['all', 'pending', 'completed', 'high'];

    final mq = MediaQuery.of(context);
    final double horizontalPad = (18.0 * (mq.size.width / 375)).clamp(12.0, 28.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF7),
      appBar: AppBar(
        title: const Text(
          'My Tasks',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: emeraldStart.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: emeraldStart.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.visibility, size: 16, color: emeraldStart),
                  const SizedBox(width: 6),
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
        ],
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshTasks,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Info Banner ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: emeraldStart.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: emeraldStart.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: emeraldStart),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _scaledText(context,
                            'This is a read-only view. Contact admin to manage tasks.',
                            TextStyle(color: emeraldStart, fontSize: 13),
                            maxLines: 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- Stats Row ---
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final double screenW = constraints.maxWidth;
                    final double scale = (screenW / 375).clamp(0.85, 1.25);
                    final double tileHeight = (72.0 * scale).clamp(60.0, 110.0);

                    final bool singleRow = constraints.maxWidth >= 420;
                    if (singleRow) {
                      return Row(
                        children: [
                          Expanded(child: _statTile('Pending', stats['pending']!, tileHeight)),
                          const SizedBox(width: 10),
                          Expanded(child: _statTile('Completed', stats['completed']!, tileHeight)),
                          const SizedBox(width: 10),
                          Expanded(child: _statTile('High', stats['high']!, tileHeight)),
                          const SizedBox(width: 10),
                          Expanded(child: _statTile('Overdue', stats['overdue']!, tileHeight)),
                        ],
                      );
                    } else {
                      final double spacing = 10;
                      final double itemWidth = (constraints.maxWidth - spacing) / 2;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: 10,
                        children: [
                          SizedBox(width: itemWidth, child: _statTile('Pending', stats['pending']!, tileHeight)),
                          SizedBox(width: itemWidth, child: _statTile('Completed', stats['completed']!, tileHeight)),
                          SizedBox(width: itemWidth, child: _statTile('High', stats['high']!, tileHeight)),
                          SizedBox(width: itemWidth, child: _statTile('Overdue', stats['overdue']!, tileHeight)),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),

                // --- Segmented Tabs (smaller pill text) ---
                _segmentedControl(tabs),
                const SizedBox(height: 16),

                // --- Search ---
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search...',
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

                // --- Tasks ---
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (filtered.isEmpty)
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
                  ...visible.map(_taskCard).toList(),

                if (filtered.length > _maxVisibleTasks)
                  TextButton(
                    onPressed: () => setState(() => _showMoreTasks = !_showMoreTasks),
                    child: Text(
                      _showMoreTasks
                          ? 'Show less'
                          : 'Show more (${filtered.length - _maxVisibleTasks} more)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------
  //   Stat Tile (responsive height)
  // -------------------------
  Widget _statTile(String label, int value, double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEAF8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: _scaledText(context, label, const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1),
          ),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
