// lib/main.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // keep intl: ^0.17.0 in pubspec.yaml

void main() {
  runApp(const MeetingsApp());
}

/// Reusable gradient colors (user-provided)
const Color emeraldStart = Color(0xFF10B981); // #10B981
const Color emeraldEnd = Color(0xFF059669); // #059669

/// A filled gradient button (use instead of ElevatedButton for consistent gradient)
class GradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const GradientButton({
    required this.child,
    required this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [emeraldStart, emeraldEnd]),
          borderRadius: borderRadius,
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius,
          child: Padding(
            padding: padding,
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient button with an icon at the left — useful for toolbar actions
class GradientIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const GradientIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GradientButton(
      padding: padding,
      borderRadius: borderRadius,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

/// Circular FAB (kept for optional wide-screen fallback)
class GradientFab extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final double size;

  const GradientFab({required this.onPressed, required this.child, this.size = 56, super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: const CircleBorder(),
      color: Colors.transparent,
      child: Ink(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [emeraldStart, emeraldEnd]),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Color(0x22059669), blurRadius: 6, offset: Offset(0, 3))
          ],
        ),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(child: DefaultTextStyle(style: const TextStyle(color: Colors.white), child: child)),
        ),
      ),
    );
  }
}

/// small circular gradient icon (replacement for IconButton)
class GradientIconCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final String? tooltip;

  const GradientIconCircle({
    required this.icon,
    required this.onPressed,
    this.size = 36,
    this.tooltip,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [emeraldStart, emeraldEnd]),
            shape: BoxShape.circle,
          ),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Center(child: Icon(icon, size: size * 0.55, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

/// NEW: horizontal pill-style floating action (like the Timeline button in your screenshot)
class GradientPillFab extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final double height;
  final BorderRadius borderRadius;

  const GradientPillFab({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.height = 44,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [emeraldStart, emeraldEnd]),
          borderRadius: borderRadius,
          boxShadow: const [BoxShadow(color: Color(0x33059669), blurRadius: 10, offset: Offset(0, 6))],
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 10),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MeetingsApp extends StatelessWidget {
  const MeetingsApp({super.key});
  @override
  Widget build(BuildContext context) {
    const emerald = Color(0xFF10B981); // Tailwind emerald-500

    final colorScheme = ColorScheme.fromSeed(seedColor: emerald);

    return MaterialApp(
      title: 'Meetings — Student Hub',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        // keep colorScheme.primary for tag colors etc.
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: emerald, // kept as a fallback for any remaining ElevatedButton usage
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            elevation: 2,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: emerald,
            side: BorderSide(color: emerald),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: emerald,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: emerald,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: colorScheme.surface,
          margin: EdgeInsets.zero,
        ),
      ),
      home: const MeetingsPage(),
    );
  }
}

/// Basic meeting model used in the demo
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
}

class MeetingsPage extends StatefulWidget {
  const MeetingsPage({super.key});

  @override
  State<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends State<MeetingsPage> {
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _displayFormat = DateFormat('EEE, MMM d, h:mm a');

  // In-memory demo storage
  final List<Meeting> _meetings = [
    Meeting(
      id: '1',
      title: 'Budget Meeting',
      type: 'project',
      purpose: 'badiet',
      datetime: DateTime.now().subtract(const Duration(days: 6)),
      location: 'Room 101',
      status: 'Not Started',
    ),
    Meeting(
      id: '2',
      title: 'Design Sync',
      type: 'project',
      purpose: 'UI review',
      datetime: DateTime.now().add(const Duration(days: 1)),
      location: 'Room 102',
      status: 'Not Started',
    ),
    Meeting(
      id: '3',
      title: 'Advising Session',
      type: 'advising',
      purpose: 'Advising students',
      datetime: DateTime.now().add(const Duration(days: 2)),
      location: '',
      meetLink: 'https://meet.example/j/789',
      status: 'Not Started',
    ),
    Meeting(
      id: '4',
      title: 'Study Group with a very long name that previously wrapped poorly',
      type: 'study group',
      purpose: 'Exam prep',
      datetime: DateTime.now().add(const Duration(days: 3)),
      location: 'Library',
      status: 'Not Started',
    ),
    Meeting(
      id: '5',
      title: 'Later Meeting (outside 7 days)',
      type: 'project',
      purpose: 'far future',
      datetime: DateTime.now().add(const Duration(days: 12)),
      location: '',
      status: 'Not Started',
    ),
  ];

  // Example students list
  final List<String> _students = [
    'Alice Johnson',
    'Bob Smith',
    'Charlie Nguyen',
    'Daniela Ruiz',
    'Eve Carter',
    'Frank Li',
  ];

  String _search = '';

  // Maximum number of visible meetings (fixed display). Change this value to show more/less.
  final int _maxVisibleMeetings = 6;

  // collapsed by default
  bool _showMoreMeetings = false;

  List<Meeting> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return List.of(_meetings);
    return _meetings.where((m) {
      final s = '${m.title} ${m.purpose ?? ''} ${m.type}'.toLowerCase();
      return s.contains(q);
    }).toList();
  }

  int get _notStartedCount => _meetings.where((m) => m.status == 'Not Started').length;
  int get _projectsCount => _meetings.where((m) => m.type == 'project').length;
  int get _virtualCount => _meetings.where((m) => m.isVirtual).length;
  int get _thisWeekCount {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1)); // Monday start
    final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return _meetings.where((m) => m.datetime.isAfter(start) && m.datetime.isBefore(end)).length;
  }

  // _nextUp returns the earliest upcoming (up to 3) meetings but only within the next 7 days.
  List<Meeting> get _nextUp {
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 7));
    final upcoming = _meetings.where((m) => m.datetime.isAfter(now) && m.datetime.isBefore(cutoff)).toList();
    upcoming.sort((a, b) => a.datetime.compareTo(b.datetime));
    return upcoming.take(3).toList();
  }

  // NEW: count of meetings within the next 7 days (inclusive from now to now + 7 days)
  int get _upcoming7DaysCount {
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 7));
    return _meetings.where((m) => m.datetime.isAfter(now) && m.datetime.isBefore(cutoff)).length;
  }

  void _openAddEditSheet({Meeting? edit}) async {
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
              existing: edit,
            ),
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        if (edit == null) {
          _meetings.add(result);
        } else {
          final idx = _meetings.indexWhere((m) => m.id == result.id);
          if (idx >= 0) _meetings[idx] = result;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(edit == null ? 'Meeting created' : 'Meeting updated')));
    }
  }

  void _deleteMeeting(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete meeting?'),
        content: const Text('This will permanently remove the meeting.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _meetings.removeWhere((m) => m.id == id);
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meeting deleted')));
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _updateStatus(Meeting m, String newStatus) {
    setState(() {
      m.status = newStatus;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status updated')));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// This is the edited stat tile to match the "Budget" screen 4-square design:
  /// - soft purple/pale background
  /// - rounded corners, subtle shadow
  /// - compact label above bold value
  Widget _buildStatTile(String label, String value, double maxWidth) {
    // keep widths reasonable on narrow screens
    final tileWidth = maxWidth.clamp(140.0, 340.0);
    return SizedBox(
      width: tileWidth,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F1FB), // pale purple / lilac background like your reference
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 6)),
          ],
          border: Border.all(color: const Color(0xFFFAF7FF)), // very light border to lift it
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 18)),
        ]),
      ),
    );
  }

  // decide whether to show schedule button in appbar or as FAB
  bool _useFabForSchedule(double width) => width < 520;

  // show-more pill for meetings area (re-usable)
  Widget _showMorePill({required bool expanded, required VoidCallback onTap}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: expanded
                  ? LinearGradient(colors: [emeraldEnd.withOpacity(0.98), emeraldStart])
                  : const LinearGradient(colors: [emeraldStart, emeraldEnd]),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [BoxShadow(color: emeraldEnd.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(expanded ? 'Show less' : 'Show more', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ),
    );
  }

  // =========================
  // New top hero (full-width Next Up) — green gradient matching buttons
  // - Flexible height (no fixed height) so it won't overflow
  // - Badge shows count for meetings within next 7 days
  // - Shows current date
  // =========================
  Widget _buildNextUpHero(double width) {
    final items = _nextUp;

    final leftIconSize = width < 360 ? 52.0 : 64.0;
    final badgeSize = width < 360 ? 48.0 : 56.0;

    final currentDateText = DateFormat('EEE, MMM d').format(DateTime.now());

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [emeraldStart, emeraldEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: emeraldEnd.withOpacity(0.18), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: icon block (reduced width)
          Container(
            width: leftIconSize,
            height: leftIconSize,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(Icons.schedule, size: leftIconSize * 0.48, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          // middle: text content (flexible; allows multiple lines)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + current date on same column (current date is subtle)
                Row(
                  children: [
                    const Expanded(child: Text('Next Up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18))),
                    Text(currentDateText, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                if (items.isEmpty)
                  Text('No upcoming meetings in the next 7 days', style: TextStyle(color: Colors.white.withOpacity(0.95)))
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: items.map((m) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // small bullet
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            // allow title to occupy up to 2 lines before truncating
                            Expanded(
                              child: Text(
                                m.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(DateFormat('MMM d').format(m.datetime), style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right: gradient square badge that matches the green buttons (shows count for next 7 days)
          Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [emeraldStart, emeraldEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: emeraldEnd.withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${_upcoming7DaysCount}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('upcoming', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final isWide = width >= 920;
      final statTileMax = (width / (isWide ? 4 : 2)) - 24;

      // computed visible meetings based on show-more flag
      final list = _filtered;
      final visible = _showMoreMeetings ? list : list.take(_maxVisibleMeetings).toList();

      return Scaffold(
        // header removed (you requested no header) — start content from body
        floatingActionButton: _useFabForSchedule(width)
            ? GradientPillFab(
                onPressed: () => _openAddEditSheet(),
                icon: Icons.add,
                label: 'Add Meeting',
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: width < 480 ? 12 : 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // NEW: Next-Up hero at the top (green gradient)
                _buildNextUpHero(width),
                const SizedBox(height: 14),

                // Lightweight search row (keeps search available)
                SizedBox(
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 20, color: Colors.black54),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search meetings...',
                              border: InputBorder.none,
                              isCollapsed: true,
                            ),
                            style: const TextStyle(fontSize: 14),
                            onChanged: (v) {
                              setState(() {
                                _search = v;
                              });
                            },
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _searchController.clear();
                                _search = '';
                              });
                            },
                            child: Icon(Icons.close, size: 18, color: Colors.black45),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Stats row: use Wrap so tiles wrap on small screens and center them
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildStatTile('Not Started', '$_notStartedCount', statTileMax),
                    _buildStatTile('This Week', '$_thisWeekCount', statTileMax),
                    _buildStatTile('Projects', '$_projectsCount', statTileMax),
                    _buildStatTile('Virtual', '$_virtualCount', statTileMax),
                  ],
                ),
                const SizedBox(height: 12),

                // MAIN CONTENT: meetings list (bottom Next Up card removed)
                if (isWide)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // LEFT: meetings column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Meetings', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...visible.map((m) => Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: MeetingCard(
                                  meeting: m,
                                  dateFormat: _displayFormat,
                                  onEdit: () => _openAddEditSheet(edit: m),
                                  onDelete: () => _deleteMeeting(m.id),
                                  onStatusChanged: (s) => _updateStatus(m, s),
                                ),
                              )),
                          if (list.isEmpty)
                            Center(child: Text('No meetings found.', style: TextStyle(color: Colors.grey.shade600))),
                          if (list.length > _maxVisibleMeetings)
                            _showMorePill(
                              expanded: _showMoreMeetings,
                              onTap: () => setState(() => _showMoreMeetings = !_showMoreMeetings),
                            ),
                          if (list.length > _maxVisibleMeetings && !_showMoreMeetings)
                            Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text('Showing ${_maxVisibleMeetings} of ${list.length} meetings', style: TextStyle(color: Colors.grey.shade600)),
                            ),
                        ],
                      ),
                    ),
                    // Note: right-side Next Up card removed per your request
                  ])
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Meetings', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...visible.map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: MeetingCard(
                              meeting: m,
                              dateFormat: _displayFormat,
                              onEdit: () => _openAddEditSheet(edit: m),
                              onDelete: () => _deleteMeeting(m.id),
                              onStatusChanged: (s) => _updateStatus(m, s),
                            ),
                          )),
                      if (list.isEmpty)
                        Center(child: Text('No meetings found.', style: TextStyle(color: Colors.grey.shade600))),
                      if (list.length > _maxVisibleMeetings)
                        _showMorePill(
                          expanded: _showMoreMeetings,
                          onTap: () => setState(() => _showMoreMeetings = !_showMoreMeetings),
                        ),
                      if (list.length > _maxVisibleMeetings && !_showMoreMeetings)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text('Showing ${_maxVisibleMeetings} of ${list.length} meetings', style: TextStyle(color: Colors.grey.shade600)),
                        ),
                      const SizedBox(height: 12),
                      // bottom Next Up card intentionally removed
                    ],
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    });
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

    final isNarrow = MediaQuery.of(context).size.width < 480;
    final locationDisplay = (meeting.location ?? '').trim().isNotEmpty ? meeting.location!.trim() : (meeting.isVirtual ? 'Online' : '');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: isNarrow
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text(meeting.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                  // replace edit icon with small gradient circle
                  GradientIconCircle(icon: Icons.edit, tooltip: 'Edit', onPressed: onEdit),
                ]),
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
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  DropdownButton<String>(
                    value: meeting.status,
                    items: ['Not Started', 'In Progress', 'Completed', 'Cancelled'].map((s) {
                      return DropdownMenuItem(value: s, child: Text(s));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) onStatusChanged(v);
                    },
                  ),
                  Row(children: [
                    if (meeting.isVirtual)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GradientButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Open ${meeting.meetLink}')));
                          },
                          child: const Text('Join'),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.red), tooltip: 'Delete'),
                  ])
                ]),
              ])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Flexible(child: Text(meeting.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                      // replace edit icon with small gradient circle
                      GradientIconCircle(icon: Icons.edit, tooltip: 'Edit', onPressed: onEdit),
                    ]),
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
                  ]),
                ),
                const SizedBox(width: 12),
                Column(children: [
                  DropdownButton<String>(
                    value: meeting.status,
                    items: ['Not Started', 'In Progress', 'Completed', 'Cancelled'].map((s) {
                      return DropdownMenuItem(value: s, child: Text(s));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) onStatusChanged(v);
                    },
                  ),
                  const SizedBox(height: 8),
                  if (meeting.isVirtual)
                    GradientButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Open ${meeting.meetLink}')));
                      },
                      child: const Text('Join'),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete',
                  ),
                ]),
              ]),
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

/// Bottom sheet for adding / editing a meeting (unchanged logic; icon buttons converted to gradient)
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

  Future<void> _pickStudents() async {
    final selected = Set<String>.from(_selectedStudents);
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Select students'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: widget.students.map((s) {
                return StatefulBuilder(
                  builder: (c, setStateInner) {
                    return CheckboxListTile(
                      title: Text(s),
                      value: selected.contains(s),
                      onChanged: (v) {
                        setStateInner(() {
                          if (v == true) selected.add(s);
                          else selected.remove(s);
                        });
                      },
                    );
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: SizedBox(
                width: 90,
                child: GradientButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Done'),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ],
        );
      },
    );
    setState(() {
      _selectedStudents = selected;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_datetime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please pick date & time')));
      return;
    }
    final meetLink = _meetLinkController.text.trim();
    if (_isVirtual && meetLink.isNotEmpty && !RegExp(r'^https?:\/\/').hasMatch(meetLink)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meet link should start with http:// or https://')));
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
      meetLink: _isVirtual ? (meetLink.isEmpty ? null : meetLink) : null,
      attendees: _selectedStudents.toList(),
    );

    Navigator.of(context).pop(meeting);
  }

  @override
  Widget build(BuildContext context) {
    final display = _datetime == null ? 'Pick date & time' : DateFormat('EEE, MMM d • h:mm a').format(_datetime!);
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 12),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(widget.existing == null ? 'Schedule Meeting' : 'Edit Meeting', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            GradientIconCircle(icon: Icons.close, tooltip: 'Close', onPressed: () => Navigator.of(context).pop()),
          ]),
          const SizedBox(height: 8),
          Form(
            key: _formKey,
            child: Column(children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
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
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: GradientIconButton(
                    icon: Icons.calendar_today,
                    label: display,
                    onPressed: _pickDateTime,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _purposeController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Purpose', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Column(children: [
                  Row(children: [
                    Checkbox(value: _isVirtual, onChanged: (v) => setState(() => _isVirtual = v ?? false)),
                    const Text('Virtual', style: TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ]),
              ]),
              if (_isVirtual) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _meetLinkController,
                  decoration: const InputDecoration(labelText: 'Meet link (optional)', border: OutlineInputBorder()),
                ),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: GradientButton(
                    onPressed: _pickStudents,
                    child: Text('Students (${_selectedStudents.length})'),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                GradientButton(
                  onPressed: _save,
                  child: Text(widget.existing == null ? 'Add' : 'Save'),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  borderRadius: BorderRadius.circular(8),
                ),
              ]),
              const SizedBox(height: 8),
              Text('Leave blank to save without a join link.', style: TextStyle(color: Colors.grey.shade600)),
            ]),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}
