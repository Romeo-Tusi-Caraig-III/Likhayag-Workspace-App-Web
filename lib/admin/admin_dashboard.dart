// lib/dashboard_page.dart
// Dashboard — Emerald theme: unify greens to _accentGreen; keep custom burger gradient as brighter two-color gradient

import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:student_workspace/admin/budget.dart';
import 'package:student_workspace/admin/profile.dart';
import 'package:student_workspace/admin/planner_dashboard.dart';
import 'package:student_workspace/admin/meetings.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, String>> tasks = [];
  List<Map<String, String>> meetings = [];
  String searchQuery = '';

  late final AnimationController _pulseController;

  // Persistent search controller (fixes rebuild / late init issues)
  final TextEditingController _searchController = TextEditingController();

  // Design tokens — consistent emerald green
  static const _cardRadius = 16.0;
  static const _borderColor = Color(0xFFE6ECE6);
  static const _accentGreen = Color(0xFF10B981); // burger token (now primary green used across buttons)
  static const _muted = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    // keep controller and searchQuery in sync
    _searchController.text = searchQuery;
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() => searchQuery = _searchController.text);
    });
    loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final rawTasks = prefs.getString('tasks') ?? '[]';
    final rawMeetings = prefs.getString('meetings') ?? '[]';

    try {
      final t = json.decode(rawTasks) as List;
      final m = json.decode(rawMeetings) as List;
      setState(() {
        tasks = t.map((e) => Map<String, String>.from(e as Map)).toList();
        meetings = m.map((e) => Map<String, String>.from(e as Map)).toList();
      });
    } catch (_) {
      setState(() {
        tasks = [];
        meetings = [];
      });
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tasks', json.encode(tasks));
    await prefs.setString('meetings', json.encode(meetings));
  }

  void addTask(String title, String due, String priority) {
    setState(() {
      tasks.add({'title': title, 'due': due, 'priority': priority});
    });
    saveData();
    _pulseController.forward(from: 0);
  }

  void addMeeting(String title, String location, String time) {
    setState(() {
      meetings.add({'title': title, 'location': location, 'time': time});
    });
    saveData();
    _pulseController.forward(from: 0);
  }

  List<Map<String, String>> get filteredTasks {
    if (searchQuery.trim().isEmpty) return tasks;
    final q = searchQuery.toLowerCase();
    return tasks.where((t) => (t['title'] ?? '').toLowerCase().contains(q)).toList();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openPlanner() {
    try {
      Navigator.of(context).push(MaterialPageRoute(builder: (c) => const PlannerPage()));
    } catch (e) {
      _showSnack('Failed to open planner: $e');
    }
  }

  void _openBudget() {
    try {
      Navigator.of(context).push(MaterialPageRoute(builder: (c) => const BudgetPage()));
    } catch (e) {
      _showSnack('Failed to open budget: $e');
    }
  }

  void _openMeetings() {
    try {
      Navigator.of(context).push(MaterialPageRoute(builder: (c) => const MeetingsPage()));
    } catch (e) {
      _showSnack('Failed to open meetings: $e');
    }
  }

  void _openCalendar() {
    try {
      Navigator.pushNamed(context, '/calendar');
      return;
    } catch (_) {}
    try {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _EmbeddedCalendarPage()));
    } catch (e) {
      _showSnack('Failed to open calendar: $e');
    }
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
        // unify all green usages to the emerald token
        return _accentGreen;
      case 'medium':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Widget _buildAppBar(BuildContext ctx) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false, // we provide a custom leading widget
      // custom leading (enhanced burger)
      leadingWidth: 72,
      leading: Padding(
        padding: const EdgeInsets.only(left: 14.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              // open drawer safely
              if (_scaffoldKey.currentState != null && !_scaffoldKey.currentState!.isDrawerOpen) {
                _scaffoldKey.currentState!.openDrawer();
              } else {
                // fallback: try Navigator
                try {
                  Scaffold.of(ctx).openDrawer();
                } catch (_) {}
              }
            },
            splashColor: _accentGreen.withOpacity(0.18),
            child: Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                // KEEP the custom burger bright two-color gradient per request
                gradient: const LinearGradient(
                  colors: [_accentGreen, _accentGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 6)),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.menu,
                  color: Colors.white,
                  size: 20,
                  semanticLabel: 'Open navigation drawer',
                ),
              ),
            ),
          ),
        ),
      ),
      // title left intentionally empty
      title: const SizedBox.shrink(),
      actions: [
        // Search chip (smaller; uses controller)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180, minWidth: 80),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _borderColor),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Icon(Icons.search, color: _muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'Search tasks...'),
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                  if (searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => searchQuery = '');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(Icons.close, size: 18, color: _muted),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        IconButton(
          tooltip: 'Notifications',
          onPressed: () => _showSnack('No notifications'),
          icon: const Icon(Icons.notifications, color: Colors.black54),
        ),

        // Profile avatar with menu
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: PopupMenuButton<int>(
            tooltip: 'Account',
            onSelected: (v) {
              if (v == 1) _openProfile();
              if (v == 2) _showSnack('Settings not implemented');
              if (v == 3) {
                try {
                  Navigator.pushReplacementNamed(context, '/login');
                } catch (_) {
                  _showSnack('/login route not defined');
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 1, child: Text('Profile')),
              const PopupMenuItem(value: 2, child: Text('Settings')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 3, child: Text('Sign Out')),
            ],
            child: CircleAvatar(
              radius: 18,
              backgroundColor: _accentGreen,
              child: const Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Good ${_morningAfternoonEvening()}, Admin', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('You have ${tasks.length} tasks and ${meetings.length} meetings this week.', style: const TextStyle(color: Color(0xFF6B7280))),
            ]),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: _accentGreen.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text(dateStr, style: const TextStyle(color: _accentGreen, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(_formatWeekdayShort(DateTime.now()), style: const TextStyle(color: _muted, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _openCalendar,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _accentGreen, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), side: BorderSide(color: _accentGreen.withOpacity(0.12))),
              child: const Text('Open Calendar'),
            ),
          ])
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              child: meetings.isEmpty
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
                          title: Text(meeting['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${meeting['location'] ?? ''} • ${meeting['time'] ?? ''}', style: const TextStyle(color: Color(0xFF6B7280))),
                          trailing: IconButton(icon: const Icon(Icons.open_in_new), onPressed: () => _showSnack('Open meeting details (not implemented)')),
                        );
                      },
                      separatorBuilder: (ctx, _) => const Divider(height: 12),
                      itemCount: meetings.length,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 170,
            child: FilledButton.icon(
              onPressed: () => showMeetingDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Schedule Meeting'),
              style: FilledButton.styleFrom(backgroundColor: _accentGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tasksCard() {
    return _modernCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cardHeader(Icons.check_box, "Today's Tasks",
              trailing: TextButton(
            onPressed: () => _showSnack('Manage not implemented'),
            style: TextButton.styleFrom(foregroundColor: _accentGreen),
            child: const Text('Manage'),
          )),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: filteredTasks.isEmpty
                  ? Padding(padding: const EdgeInsets.only(top: 10), child: Text('No tasks', style: TextStyle(color: _muted)))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filteredTasks.length,
                      separatorBuilder: (ctx, _) => const SizedBox(height: 6),
                      itemBuilder: (ctx, i) {
                        final t = filteredTasks[i];
                        final pr = t['priority'] ?? 'medium';
                        return GestureDetector(
                          onTap: () => _showSnack('Tap to mark complete (not implemented)'),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEFEFEF))),
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(t['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  Text('Due: ${t['due'] ?? ''}', style: const TextStyle(color: Color(0xFF6B7280))),
                                ]),
                              ),
                              Chip(
                                label: Text((pr).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                backgroundColor: _priorityColor(pr),
                                visualDensity: VisualDensity.compact,
                              )
                            ]),
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
              onPressed: () => showTaskDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
              style: OutlinedButton.styleFrom(foregroundColor: _accentGreen, side: BorderSide(color: _accentGreen.withOpacity(0.14))),
            ),
          ),
        ]),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.rocket_launch, color: _accentGreen), const SizedBox(width: 10), const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.w700))]),
          const SizedBox(height: 12),
          Column(
            children: actions.map((a) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: _accentGreen),
                  onPressed: a['fn'] as void Function()?,
                  child: Row(children: [Icon(a['icon'] as IconData, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(a['label'] as String, style: const TextStyle(color: Colors.white))), const Icon(Icons.chevron_right, color: Colors.white)]),
                ),
              );
            }).toList(),
          )
        ]),
      ),
    );
  }

  Widget _campusCard() {
    return _modernCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Campus Life', style: TextStyle(fontWeight: FontWeight.w700)),
          TextButton(onPressed: () => _showSnack('Campus feed not implemented'), child: Text('View More', style: TextStyle(color: _accentGreen))),
        ])),
        ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
          child: CachedNetworkImage(
            imageUrl: 'https://images.unsplash.com/photo-1503676260728-ead5a08ddfd2?q=80&w=1280&auto=format&fit=crop',
            fit: BoxFit.cover,
            height: 160,
            width: double.infinity,
            fadeInDuration: const Duration(milliseconds: 420),
            placeholder: (ctx, url) => Container(height: 160, alignment: Alignment.center, color: const Color(0xFFF3F4F6), child: CircularProgressIndicator(color: _accentGreen)),
            errorWidget: (ctx, url, err) => Container(height: 160, color: const Color(0xFFF3F4F6), alignment: Alignment.center, child: const Text('Campus life')),
          ),
        ),
      ]),
    );
  }

  Widget _modernCard({required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_cardRadius), border: Border.all(color: _borderColor), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 14, offset: const Offset(0, 8))]),
      child: child,
    );
  }

  Widget _cardHeader(IconData icon, String title, {Widget? trailing}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [Icon(icon, size: 18, color: const Color(0xFF111827)), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w700))]),
      if (trailing != null) trailing
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      appBar: PreferredSize(preferredSize: const Size.fromHeight(88), child: _buildAppBar(context)),
      backgroundColor: const Color(0xFFF7FBF7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _heroHeader(context),
            const SizedBox(height: 18),
            LayoutBuilder(builder: (ctx, bc) {
              final wide = bc.maxWidth >= 1000;
              if (wide) {
                return Row(children: [
                  Expanded(flex: 4, child: _scheduleCard()),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: _tasksCard()),
                  const SizedBox(width: 16),
                  SizedBox(width: 320, child: _quickActionsCard()),
                ]);
              } else {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _scheduleCard(),
                  const SizedBox(height: 12),
                  _tasksCard(),
                  const SizedBox(height: 12),
                  _quickActionsCard(),
                ]);
              }
            }),
            const SizedBox(height: 18),
            _campusCard(),
            const SizedBox(height: 28),
          ]),
        ),
      ),
      // FAB removed per request
    );
  }

  // MODERN EMERALD DRAWER
  Drawer _buildDrawer() {
    // list of navigation items
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
          // unify drawer greens to the accent token
          gradient: LinearGradient(
          colors: [_accentGreen, const Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18),
                child: Row(
                  children: [
                    CircleAvatar(radius: 28, backgroundColor: Colors.white24, child: const Icon(Icons.school, color: Colors.white, size: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                        Text('Student Hub', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Academic Success', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ]),
                    ),
                    // small settings icon in header
                    IconButton(
                      onPressed: () => _showSnack('Settings not implemented'),
                      icon: const Icon(Icons.settings, color: Colors.white70),
                    )
                  ],
                ),
              ),

              // search/quick actions inside drawer (optional)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  onSubmitted: (_) => Navigator.pop(context),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search tasks...',
                    hintStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white12,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // nav items
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 8, indent: 12, endIndent: 12),
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
                              Expanded(child: Text(it['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
                              const Icon(Icons.chevron_right, color: Colors.white70)
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // footer actions (removed the white + button)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // sign out
                          try {
                            Navigator.pushReplacementNamed(context, '/login');
                          } catch (_) {
                            _showSnack('/login route not defined');
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
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void showTaskDialog(BuildContext context) {
    String title = '';
    String due = '';
    String priority = 'medium';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Task'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(decoration: const InputDecoration(labelText: 'Title'), onChanged: (v) => title = v),
          TextField(decoration: const InputDecoration(labelText: 'Due (e.g. Nov 30, 5 PM)'), onChanged: (v) => due = v),
          DropdownButtonFormField<String>(
            value: priority,
            items: ['high', 'medium', 'low'].map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
            onChanged: (v) => priority = v ?? 'medium',
            decoration: const InputDecoration(labelText: 'Priority'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (title.trim().isEmpty) {
                _showSnack('Please provide a title');
                return;
              }
              addTask(title.trim(), due.trim(), priority);
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void showMeetingDialog(BuildContext context) {
    String title = '';
    String location = '';
    String time = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Meeting'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(decoration: const InputDecoration(labelText: 'Title'), onChanged: (v) => title = v),
          TextField(decoration: const InputDecoration(labelText: 'Location'), onChanged: (v) => location = v),
          TextField(decoration: const InputDecoration(labelText: 'Time'), onChanged: (v) => time = v),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (title.trim().isEmpty) {
                _showSnack('Please enter a title');
                return;
              }
              addMeeting(title.trim(), location.trim(), time.trim());
              Navigator.pop(context);
            },
            child: const Text('Schedule'),
          ),
        ],
      ),
    );
  }

  // Date formatting helpers
  static String _formatDateShort(DateTime d) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${monthNames[d.month - 1]} ${d.day}, ${d.year}';
  }

  static String _formatWeekdayShort(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(d.weekday - 1) % 7];
  }
}

class _EmbeddedCalendarPage extends StatelessWidget {
  const _EmbeddedCalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar'), backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE6ECE6))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Today — ${_formatDateSmall(today)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('No events scheduled', style: TextStyle(color: Color(0xFF6B7280))),
              ]),
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
            ]),
          ),
          const SizedBox(height: 16),
          const Expanded(child: Center(child: Text('Mini calendar (placeholder)', style: TextStyle(color: Colors.grey)))),
        ]),
      ),
    );
  }

  static String _formatDateSmall(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
