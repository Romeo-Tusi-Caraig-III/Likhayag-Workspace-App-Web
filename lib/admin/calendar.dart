// lib/calendar_page.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart'; // used for header date formatting

class Event {
  final String title;
  final DateTime start;
  final String type;
  final String status;
  final String location;
  final String description;

  Event({
    required this.title,
    required this.start,
    required this.type,
    required this.status,
    this.location = '',
    this.description = '',
  });
}

void main() {
  runApp(const MyApp());
}

class AppStyles {
  // color palette (single source of truth)
  static const Color primary = Color(0xFF10B981); // emeraldStart
  static const Color primaryDark = Color(0xFF059669); // emeraldEnd
  static const Color softBg = Color(0xFFF7F4F8);
  static const double borderRadius = 10.0;
  static Color iconButtonColor = primaryDark;
}

/// Small reusable Meetings-style gradient pill fab (matches your Meetings page)
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
          gradient: const LinearGradient(colors: [AppStyles.primary, AppStyles.primaryDark]),
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.light();
    return MaterialApp(
      title: 'Calendar Demo',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: AppStyles.softBg,
        colorScheme: base.colorScheme.copyWith(primary: AppStyles.primary),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppStyles.primary,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(),
        outlinedButtonTheme: OutlinedButtonThemeData(),
        textButtonTheme: TextButtonThemeData(),
        iconTheme: IconThemeData(color: AppStyles.iconButtonColor),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
      ),
      home: const CalendarPage(),
    );
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _displayMonth = DateTime.now();
  DateTime? _selectedDate;
  final Map<String, List<Event>> _events = {};
  final DateFormat _labelFormat = DateFormat('EEE, MMM d, yyyy');

  String _dateKey(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String _monthLabel(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  String _dateLabel(DateTime d) => _labelFormat.format(d);

  String _timeLabel(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    const padding = 12.0;

    return Scaffold(
      // important: extendBody so FAB floats above bottom nav consistently
      extendBody: true,
      appBar: null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: padding),
          child: Column(
            children: [
              _headerRightChips(),
              const SizedBox(height: 12),
              _monthNavigator(),
              const SizedBox(height: 10),
              _weekLabels(),
              const SizedBox(height: 8),
              Expanded(child: _monthGrid()),
            ],
          ),
        ),
      ),

      // Use Meetings-style floating pill (no manual padding wrapper)
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: GradientPillFab(
        onPressed: () => _showAddEventDialog(context, DateTime.now()),
        icon: Icons.add,
        label: 'Add Event',
      ),
    );
  }

  // ------------------ HEADER ------------------
  Widget _headerRightChips() {
    final today = DateTime.now();
    final todayLabel = DateFormat('EEE, MMM d').format(today);

    final now = DateTime.now();
    final weekEnd = now.add(const Duration(days: 7));
    final upcomingCount = _events.entries
        .expand((e) => e.value)
        .where((ev) {
          final s = ev.start;
          return (s.isAfter(now.subtract(const Duration(seconds: 1))) &&
              s.isBefore(weekEnd.add(const Duration(seconds: 1))));
        })
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Calendar',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppStyles.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppStyles.primary.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: AppStyles.primaryDark),
                    const SizedBox(width: 8),
                    Text(todayLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppStyles.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_available, size: 14, color: AppStyles.primaryDark),
                    const SizedBox(width: 6),
                    Text('$upcomingCount upcoming', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------ MONTH NAVIGATOR ------------------
  Widget _monthNavigator() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          color: AppStyles.iconButtonColor,
          onPressed: () {
            setState(() {
              _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1, 1);
            });
          },
        ),
        Expanded(
          child: Center(
            child: Text(
              _monthLabel(_displayMonth),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          color: AppStyles.iconButtonColor,
          onPressed: () {
            setState(() {
              _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1, 1);
            });
          },
        ),
      ],
    );
  }

  // ------------------ WEEK LABELS ------------------
  Widget _weekLabels() {
    final labels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    return Row(
      children: labels
          .map(
            (d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.w600)))),
          )
          .toList(),
    );
  }

  // ------------------ GRID ------------------
  Widget _monthGrid() {
    final first = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final firstWeekday = first.weekday % 7;
    final daysInMonth = DateTime(_displayMonth.year, _displayMonth.month + 1, 0).day;
    final totalTiles = ((firstWeekday + daysInMonth) / 7).ceil() * 7;

    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
      ),
      itemCount: totalTiles,
      physics: const ClampingScrollPhysics(),
      itemBuilder: (context, index) {
        final int dayIndex = index - firstWeekday;
        if (dayIndex < 0 || dayIndex >= daysInMonth) return _emptyTile();
        final date = DateTime(_displayMonth.year, _displayMonth.month, dayIndex + 1);
        return _dayTile(date);
      },
    );
  }

  Widget _emptyTile() {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE8EAEF)),
        ),
      ),
    );
  }

  Widget _dayTile(DateTime date) {
    final key = _dateKey(date);
    final events = _events[key] ?? [];
    final todayKey = _dateKey(DateTime.now());
    final isToday = key == todayKey;
    final hasEvents = events.isNotEmpty;
    final isSelected = _selectedDate != null && _dateKey(_selectedDate!) == key;

    Color bgColor;
    Color textColor;
    Border? border;

    if (isSelected) {
      bgColor = AppStyles.primary;
      textColor = Colors.white;
      border = Border.all(color: AppStyles.primaryDark, width: 1.5);
    } else if (hasEvents) {
      bgColor = AppStyles.primary.withOpacity(0.05);
      textColor = isToday ? AppStyles.primary : Colors.black87;
      border = Border.all(color: const Color(0xFFE8EAEF));
    } else if (isToday) {
      bgColor = AppStyles.primary.withOpacity(0.05);
      textColor = AppStyles.primary;
      border = Border.all(color: const Color(0xFFE8EAEF));
    } else {
      bgColor = Colors.white;
      textColor = Colors.black87;
      border = Border.all(color: const Color(0xFFE8EAEF));
    }

    final int maxDots = 3;
    final int dotsToShow = math.min(events.length, maxDots);
    final int overflow = events.length - dotsToShow;

    return Padding(
      padding: const EdgeInsets.all(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() {
            _selectedDate = date;
          });
          _openDayEvents(date);
        },
        onLongPress: () => _showAddEventDialog(context, date),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: border,
          ),
          child: ClipRect(
            child: SizedBox.expand(
              child: Stack(
                children: [
                  Positioned(
                    top: 6,
                    left: 8,
                    right: 8,
                    child: Text(
                      "${date.day}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (events.isNotEmpty)
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 6,
                      child: Row(
                        children: [
                          for (int i = 0; i < dotsToShow; i++)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : AppStyles.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          if (overflow > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : AppStyles.primary.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "+$overflow",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppStyles.primaryDark,
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
        ),
      ),
    );
  }

  void _openDayEvents(DateTime date) {
    final key = _dateKey(date);
    final events = _events[key] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          color: Colors.black.withOpacity(0.18),
          child: DraggableScrollableSheet(
            initialChildSize: 0.5,
            maxChildSize: 0.9,
            builder: (context, controller) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            _dateLabel(date),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            Navigator.pop(context);
                            _showAddEventDialog(context, date);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: events.isEmpty
                          ? const Center(child: Text("No events for this day."))
                          : ListView.separated(
                              controller: controller,
                              itemBuilder: (context, index) {
                                final e = events[index];
                                return ListTile(
                                  title: Text(e.title),
                                  subtitle: Text("${_timeLabel(e.start)} • ${e.type} • ${e.status}"),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: AppStyles.iconButtonColor,
                                    onPressed: () {
                                      setState(() {
                                        _events[key]?.removeAt(index);
                                        if ((_events[key]?.isEmpty ?? true)) _events.remove(key);
                                      });
                                      Navigator.pop(context);
                                      _openDayEvents(date);
                                    },
                                  ),
                                  onTap: () {
                                    _showAddEventDialog(context, date, existing: e);
                                  },
                                );
                              },
                              separatorBuilder: (_, __) => const Divider(),
                              itemCount: events.length,
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showAddEventDialog(
    BuildContext context,
    DateTime date, {
    Event? existing,
  }) async {
    final formKey = GlobalKey<FormState>();

    String title = existing?.title ?? '';
    DateTime start = existing?.start ?? DateTime(date.year, date.month, date.day, 9);
    String type = existing?.type ?? 'Select';
    String status = existing?.status ?? 'Not Started';
    String location = existing?.location ?? '';
    String description = existing?.description ?? '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final mq = MediaQuery.of(sheetContext);
        return Padding(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: Container(
            color: Colors.black.withOpacity(0.18),
            child: DraggableScrollableSheet(
              initialChildSize: 0.55,
              minChildSize: 0.35,
              maxChildSize: 0.95,
              expand: false,
              builder: (contextDS, controller) {
                // === START: STYLED CONTAINER WITH REQUESTED CHANGES ===
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    controller: controller,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: StatefulBuilder(
                        builder: (contextSB, setStateSB) {
                          return Form(
                            key: formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // header: centered title + circular green close on right
                                Row(
                                  children: [
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        existing == null ? "Add Event" : "Edit Event",
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    // circular green close to match Meetings style
                                    Material(
                                      color: AppStyles.primary,
                                      shape: const CircleBorder(),
                                      elevation: 4,
                                      child: IconButton(
                                        splashRadius: 20,
                                        icon: const Icon(Icons.close, color: Colors.white),
                                        onPressed: () => Navigator.pop(sheetContext),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // Title (filled look)
                                TextFormField(
                                  initialValue: title,
                                  decoration: InputDecoration(
                                    hintText: "Title",
                                    filled: true,
                                    fillColor: const Color(0xFFF6F7FB),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.transparent),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.transparent),
                                    ),
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? "Please enter a title" : null,
                                  onChanged: (v) => title = v,
                                ),

                                const SizedBox(height: 12),

                                // Row with Type (left) and a gradient "Pick date & time" pill (right).
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: type,
                                        isExpanded: true,
                                        items: ["Select", "Class", "Exam", "Meeting", "Personal"]
                                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                            .toList(),
                                        onChanged: (v) {
                                          if (v != null) setStateSB(() => type = v);
                                        },
                                        decoration: InputDecoration(
                                          hintText: "Type",
                                          filled: true,
                                          fillColor: const Color(0xFFF6F7FB),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Pick date & time button with gradient look (keeps original showDatePicker/time pick)
                                    SizedBox(
                                      height: 44,
                                      child: GradientPillFab(
                                        onPressed: () async {
                                          final pickedDate = await showDatePicker(
                                            context: sheetContext,
                                            initialDate: start,
                                            firstDate: DateTime(2000),
                                            lastDate: DateTime(2100),
                                          );
                                          if (pickedDate == null) return;

                                          final pickedTime = await showTimePicker(
                                            context: sheetContext,
                                            initialTime: TimeOfDay.fromDateTime(start),
                                          );

                                          setStateSB(() {
                                            start = DateTime(
                                              pickedDate.year,
                                              pickedDate.month,
                                              pickedDate.day,
                                              pickedTime?.hour ?? start.hour,
                                              pickedTime?.minute ?? start.minute,
                                            );
                                          });
                                        },
                                        icon: Icons.calendar_today,
                                        label: "Pick date & time",
                                        height: 44,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // Status dropdown (full width)
                                DropdownButtonFormField<String>(
                                  value: status,
                                  isExpanded: true,
                                  items: ["Not Started", "In Progress", "Completed"]
                                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) setStateSB(() => status = v);
                                  },
                                  decoration: InputDecoration(
                                    hintText: "Status",
                                    filled: true,
                                    fillColor: const Color(0xFFF6F7FB),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Location (full width) — removed Virtual checkbox per request
                                TextFormField(
                                  initialValue: location,
                                  decoration: InputDecoration(
                                    hintText: "Location",
                                    filled: true,
                                    fillColor: const Color(0xFFF6F7FB),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                  onChanged: (v) => location = v,
                                ),

                                const SizedBox(height: 12),

                                // Description / Purpose (filled, multi-line)
                                TextFormField(
                                  initialValue: description,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    hintText: "Purpose",
                                    filled: true,
                                    fillColor: const Color(0xFFF6F7FB),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                  onChanged: (v) => description = v,
                                ),

                                const SizedBox(height: 16),

                                // Action row: right-aligned Cancel and Save (Students/Add removed)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(sheetContext),
                                      child: const Text("Cancel"),
                                      style: TextButton.styleFrom(foregroundColor: AppStyles.primaryDark),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        if (formKey.currentState!.validate()) {
                                          final newEvent = Event(
                                            title: title,
                                            start: start,
                                            type: type,
                                            status: status,
                                            location: location,
                                            description: description,
                                          );

                                          final key = _dateKey(DateTime(start.year, start.month, start.day));

                                          if (existing != null) {
                                            final oldKey = _dateKey(existing.start);
                                            _events[oldKey]?.remove(existing);
                                            if ((_events[oldKey]?.isEmpty ?? true)) {
                                              _events.remove(oldKey);
                                            }
                                          }

                                          setState(() {
                                            _events.putIfAbsent(key, () => []);
                                            _events[key]!.add(newEvent);
                                            _selectedDate = DateTime(start.year, start.month, start.day);
                                          });

                                          Navigator.pop(sheetContext);
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppStyles.primary,
                                        foregroundColor: Colors.white, // ensures white text
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text("Save", style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
                // === END: STYLED CONTAINER ===
              },
            ),
          ),
        );
      },
    );
  }
}
