// lib/admin/admin_dashboard.dart
// Complete Admin Dashboard with Supabase integration

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'budget.dart';
import 'profile.dart';
import 'planner_dashboard.dart';
import 'meetings.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, String>> tasks = [];
  List<Map<String, String>> meetings = [];
  String searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  bool _isRefreshing = false;

  static const _cardRadius = 16.0;
  static const _borderColor = Color(0xFFE6ECE6);
  static const _accentGreen = Color(0xFF10B981);
  static const _muted = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() => searchQuery = _searchController.text);
    });
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
      final tasksData = await ApiService.getTasks();
      final meetingsData = await ApiService.getMeetings();

      if (!mounted) return;

      setState(() {
        // Convert API data to local format
        tasks.clear();
        for (var task in tasksData) {
          tasks.add({
            'title': task['title'] ?? '',
            'due': task['due'] ?? '',
            'priority': task['priority'] ?? 'medium',
          });
        }

        meetings.clear();
        for (var meeting in meetingsData) {
          final datetime = DateTime.tryParse(meeting['datetime'] ?? '');
          final time = datetime != null ? DateFormat('h:mm a').format(datetime) : '';
          
          meetings.add({
            'title': meeting['title'] ?? '',
            'location': meeting['location'] ?? 'TBA',
            'time': time,
          });
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
      final tasksData = await ApiService.getTasks();
      final meetingsData = await ApiService.getMeetings();

      if (!mounted) return;

      setState(() {
        tasks.clear();
        for (var task in tasksData) {
          tasks.add({
            'title': task['title'] ?? '',
            'due': task['due'] ?? '',
            'priority': task['priority'] ?? 'medium',
          });
        }

        meetings.clear();
        for (var meeting in meetingsData) {
          final datetime = DateTime.tryParse(meeting['datetime'] ?? '');
          final time = datetime != null ? DateFormat('h:mm a').format(datetime) : '';
          
          meetings.add({
            'title': meeting['title'] ?? '',
            'location': meeting['location'] ?? 'TBA',
            'time': time,
          });
        }

        _isRefreshing = false;
      });

      _showSnack('Dashboard refreshed');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRefreshing = false);
      _showSnack('Failed to refresh: $e');
    }
  }

  List<Map<String, String>> get filteredTasks {
    if (searchQuery.trim().isEmpty) return tasks;
    final q = searchQuery.toLowerCase();
    return tasks.where((t) => (t['title'] ?? '').toLowerCase().contains(q)).toList();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _openPlanner() {
    try {
      Navigator.of(context).push(MaterialPageRoute(builder: (c) => PlannerPage()));
    } catch (e) {
      _showSnack('Failed to open planner: $e');
    }
  }

  void _openBudget() {
    try {
      Navigator.of(context).push(MaterialPageRoute(builder: (c) => BudgetPage()));
    } catch (e) {
      _showSnack('Failed to open budget: $e');
    }
  }

  void _openMeetings() {
    try {
      Navigator.of(context).push(MaterialPageRoute(builder: (c) => MeetingsPage()));
    } catch (e) {
      _showSnack('Failed to open meetings: $e');
    }
  }

  void _openCalendar() {
    _showSnack('Calendar feature - integrate your calendar_page.dart here');
  }

  void _openProfile() {
    try {
      Navigator.of(context).push(MaterialPageRoute(builder: (c) => ProfilePage()));
    } catch (e) {
      _showSnack('Failed to open profile: $e');
    }
  }

  Color _priorityColor(String p) {
    switch ((p).toLowerCase()) {
      case 'high':
        return Colors.red.shade500;
      case 'low':
        return _accentGreen;
      case 'medium':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Widget _buildTopControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  if (_scaffoldKey.currentState != null && !_scaffoldKey.currentState!.isDrawerOpen) {
                    _scaffoldKey.currentState!.openDrawer();
                  }
                },
                child: Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _accentGreen,
                  ),
                  child: const Center(child: Icon(Icons.menu, color: Colors.white, size: 20)),
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _borderColor),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search, color: Color(0xFF6B7280)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'Search tasks...',
                      ),
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                  if (_isRefreshing)
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      onPressed: _refreshData,
                      icon: const Icon(Icons.refresh, color: Colors.black54),
                      tooltip: 'Refresh',
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroHeader(BuildContext c) {
    final dateStr = _formatDateShort(DateTime.now());
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 8))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Good ${_morningAfternoonEvening()}, Admin',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('You have ${tasks.length} tasks and ${meetings.length} meetings.',
                    style: const TextStyle(color: Color(0xFF6B7280))),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _accentGreen.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(dateStr, style: const TextStyle(color: _accentGreen, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(_formatWeekdayShort(DateTime.now()),
                        style: const TextStyle(color: _muted, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _openCalendar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _accentGreen,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  side: BorderSide(color: _accentGreen.withOpacity(0.12)),
                ),
                child: const Text('Calendar'),
              ),
            ],
          )
        ],
      ),
    );
  }

  static String _morningAfternoonEvening() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }

  Widget _scheduleCard() {
    return _modernCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(Icons.calendar_today, "Today's Schedule",
                trailing: TextButton(
                  onPressed: _openCalendar,
                  style: TextButton.styleFrom(foregroundColor: _accentGreen),
                  child: const Text('View All'),
                )),
            const SizedBox(height: 12),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : meetings.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text('No meetings scheduled', style: TextStyle(color: _muted)),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemBuilder: (ctx, i) {
                              final meeting = meetings[i];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(meeting['title'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('${meeting['location'] ?? ''} • ${meeting['time'] ?? ''}',
                                    style: const TextStyle(color: Color(0xFF6B7280))),
                                trailing: IconButton(
                                  icon: const Icon(Icons.open_in_new),
                                  onPressed: _openMeetings,
                                ),
                              );
                            },
                            separatorBuilder: (ctx, _) => const Divider(height: 12),
                            itemCount: meetings.take(3).length,
                          ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 170,
              child: FilledButton.icon(
                onPressed: _openMeetings,
                icon: const Icon(Icons.add),
                label: const Text('Meetings'),
                style: FilledButton.styleFrom(
                  backgroundColor: _accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tasksCard() {
    return _modernCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(Icons.check_box, "Today's Tasks",
                trailing: TextButton(
                  onPressed: _openPlanner,
                  style: TextButton.styleFrom(foregroundColor: _accentGreen),
                  child: const Text('Manage'),
                )),
            const SizedBox(height: 12),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredTasks.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text('No tasks', style: TextStyle(color: _muted)))
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filteredTasks.take(3).length,
                            separatorBuilder: (ctx, _) => const SizedBox(height: 6),
                            itemBuilder: (ctx, i) {
                              final t = filteredTasks[i];
                              final pr = t['priority'] ?? 'medium';
                              return GestureDetector(
                                onTap: _openPlanner,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFEFEFEF)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(t['title'] ?? '',
                                                style: const TextStyle(fontWeight: FontWeight.w600)),
                                            const SizedBox(height: 6),
                                            Text('Due: ${t['due'] ?? 'TBA'}',
                                                style: const TextStyle(color: Color(0xFF6B7280))),
                                          ],
                                        ),
                                      ),
                                      Chip(
                                        label: Text((pr).toUpperCase(),
                                            style: const TextStyle(
                                                color: Colors.white, fontWeight: FontWeight.w700)),
                                        backgroundColor: _priorityColor(pr),
                                        visualDensity: VisualDensity.compact,
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 150,
              child: OutlinedButton.icon(
                onPressed: _openPlanner,
                icon: const Icon(Icons.add),
                label: const Text('Add Task'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accentGreen,
                  side: BorderSide(color: _accentGreen.withOpacity(0.14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionsCard() {
    final actions = [
      {'icon': Icons.calendar_today, 'label': 'Calendar', 'fn': _openCalendar},
      {'icon': Icons.note, 'label': 'Planner', 'fn': _openPlanner},
      {'icon': Icons.account_balance_wallet, 'label': 'Budget', 'fn': _openBudget},
      {'icon': Icons.video_call, 'label': 'Meetings', 'fn': _openMeetings},
    ];

    return _modernCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.rocket_launch, color: _accentGreen),
              const SizedBox(width: 10),
              const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.w700))
            ]),
            const SizedBox(height: 12),
            Column(
              children: actions.map((a) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: _accentGreen,
                    ),
                    onPressed: a['fn'] as void Function()?,
                    child: Row(
                      children: [
                        Icon(a['icon'] as IconData, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(a['label'] as String, style: const TextStyle(color: Colors.white)),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white)
                      ],
                    ),
                  ),
                );
              }).toList(),
            )
          ],
        ),
      ),
    );
  }

  Widget _modernCard({required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 14, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }

  Widget _cardHeader(IconData icon, String title, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Icon(icon, size: 18, color: const Color(0xFF111827)),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700))
        ]),
        if (trailing != null) trailing
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      backgroundColor: const Color(0xFFF7FBF7),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopControls(),
                const SizedBox(height: 12),
                _heroHeader(context),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (ctx, bc) {
                  final wide = bc.maxWidth >= 1000;
                  if (wide) {
                    return Row(
                      children: [
                        Expanded(flex: 4, child: _scheduleCard()),
                        const SizedBox(width: 16),
                        Expanded(flex: 4, child: _tasksCard()),
                        const SizedBox(width: 16),
                        SizedBox(width: 320, child: _quickActionsCard()),
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _scheduleCard(),
                        const SizedBox(height: 12),
                        _tasksCard(),
                        const SizedBox(height: 12),
                        _quickActionsCard(),
                      ],
                    );
                  }
                }),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Drawer _buildDrawer() {
    final items = [
      {'icon': Icons.home, 'title': 'Home', 'action': () => Navigator.pop(context)},
      {'icon': Icons.calendar_today, 'title': 'Calendar', 'action': () { Navigator.pop(context); _openCalendar(); }},
      {'icon': Icons.note, 'title': 'Planner', 'action': () { Navigator.pop(context); _openPlanner(); }},
      {'icon': Icons.account_balance_wallet, 'title': 'Budget', 'action': () { Navigator.pop(context); _openBudget(); }},
      {'icon': Icons.video_call, 'title': 'Meetings', 'action': () { Navigator.pop(context); _openMeetings(); }},
      {'icon': Icons.person, 'title': 'Profile', 'action': () { Navigator.pop(context); _openProfile(); }},
    ];

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_accentGreen, const Color(0xFF064e3b)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white24,
                      child: const Icon(Icons.school, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Student Hub',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Admin Dashboard',
                              style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white12, height: 8, indent: 12, endIndent: 12),
                  itemBuilder: (ctx, i) {
                    final it = items[i];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: it['action'] as void Function()?,
                        splashColor: Colors.white24,
                        highlightColor: Colors.white10,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(it['icon'] as IconData, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(it['title'] as String,
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.white70)
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await ApiService.logout();
                      if (!mounted) return;
                      Navigator.pushReplacementNamed(context, '/login');
                    } catch (_) {
                      _showSnack('Logout failed');
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text('Sign out', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    backgroundColor: Colors.white10,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDateShort(DateTime d) {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${monthNames[d.month - 1]} ${d.day}, ${d.year}';
  }

  static String _formatWeekdayShort(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(d.weekday - 1) % 7];
  }
}