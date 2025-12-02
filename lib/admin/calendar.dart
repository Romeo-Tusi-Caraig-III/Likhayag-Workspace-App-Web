// lib/calendar_page.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui'; // for ImageFilter.blur
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
  // updated to match the burger icon green across the app
  static const Color primary = Color(0xFF10B981); // burger / bright emerald
  static const Color primaryDark = Color(0xFF059669); // darker stop used in burger gradient
  static const Color softBg = Color(0xFFF7F4F8);
  static const double borderRadius = 10.0;

  // Elevated / primary button style (returns ButtonStyle for ElevatedButton usage)
  static ButtonStyle elevatedPrimaryStyle({double minWidth = 88, double height = 44}) {
    return ElevatedButton.styleFrom(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      minimumSize: Size(minWidth, height),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      elevation: 6,
    );
  }

  // Outlined / secondary style
  static ButtonStyle outlinedStyle({double minWidth = 72, double height = 40}) {
    return OutlinedButton.styleFrom(
      foregroundColor: primaryDark,
      minimumSize: Size(minWidth, height),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      side: BorderSide(color: primary.withOpacity(0.18)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
    );
  }

  // subtle text button used for low-priority actions
  static ButtonStyle textActionStyle({double minWidth = 64, double height = 36}) {
    return TextButton.styleFrom(
      foregroundColor: primaryDark,
      minimumSize: Size(minWidth, height),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
    );
  }

  // icon tint
  static Color iconButtonColor = primaryDark;
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
        elevatedButtonTheme: ElevatedButtonThemeData(style: AppStyles.elevatedPrimaryStyle()),
        outlinedButtonTheme: OutlinedButtonThemeData(style: AppStyles.outlinedStyle()),
        textButtonTheme: TextButtonThemeData(style: AppStyles.textActionStyle()),
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
  final Map<String, List<Event>> _events = {}; // key: YYYY-MM-DD
  final DateFormat _labelFormat = DateFormat('EEE, MMM d, yyyy');

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text("Calendar"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: padding),
          child: Column(
            children: [
              _headerCard(), // replaced top-right add button with today's date & upcoming counter
              const SizedBox(height: 10),
              _monthNavigator(),
              const SizedBox(height: 10),
              _weekLabels(),
              const SizedBox(height: 8),
              Expanded(child: _monthGrid()),
            ],
          ),
        ),
      ),

      // Bottom-right Add Event button styled to match AppStyles
      floatingActionButton: SizedBox(
        height: 56,
        child: FloatingActionButton.extended(
          onPressed: () => _showAddEventDialog(context, DateTime.now()),
          icon: const Icon(Icons.add),
          label: const Text(
            "Add Event",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppStyles.primary,
          foregroundColor: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ------------------ HEADER CARD ------------------
  Widget _headerCard() {
    final today = DateTime.now();
    final todayLabel = DateFormat('EEE, MMM d').format(today);

    // only count upcoming events within the next 7 days (inclusive)
    final now = DateTime.now();
    final weekEnd = now.add(const Duration(days: 7));
    final upcomingCount = _events.entries
        .expand((e) => e.value)
        .where((ev) {
          final s = ev.start;
          // include events that start from now up to and including weekEnd
          return (s.isAfter(now.subtract(const Duration(seconds: 1))) && s.isBefore(weekEnd.add(const Duration(seconds: 1))));
        })
        .length;

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                "Calendar",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),

            // Today + upcoming counter replaces the previous top-right Add Event button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  todayLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppStyles.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppStyles.primary.withOpacity(0.12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_note, size: 14, color: AppStyles.primaryDark),
                      const SizedBox(width: 6),
                      Text(
                        "$upcomingCount upcoming",
                        style: TextStyle(
                          color: AppStyles.primaryDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
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
            (d) => Expanded(
                child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.w600)))),
          )
          .toList(),
    );
  }

  // ------------------ CALENDAR GRID ------------------
  Widget _monthGrid() {
    final first = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final firstWeekday = first.weekday % 7; // Sunday = 0
    final daysInMonth =
        DateTime(_displayMonth.year, _displayMonth.month + 1, 0).day;

    // Fill full rows (weeks)
    final int totalTiles =
        ((firstWeekday + daysInMonth) / 7).ceil() * 7;

    // non-bouncy, smooth scrolling: use ClampingScrollPhysics
    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0, // square cells
      ),
      itemCount: totalTiles,
      physics: const ClampingScrollPhysics(),
      itemBuilder: (context, index) {
        final int dayIndex = index - firstWeekday;
        if (dayIndex < 0 || dayIndex >= daysInMonth) {
          return _emptyTile();
        } else {
          final date = DateTime(
              _displayMonth.year, _displayMonth.month, dayIndex + 1);
          return _dayTile(date);
        }
      },
    );
  }

  // ------------------ EMPTY TILE ------------------
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

  // ------------------ DAY TILE (NO OVERFLOW) ------------------
  Widget _dayTile(DateTime date) {
    final key = _dateKey(date);
    final events = _events[key] ?? [];

    final todayKey = _dateKey(DateTime.now());
    final isToday = key == todayKey;
    final hasEvents = events.isNotEmpty;
    final isSelected =
        _selectedDate != null && _dateKey(_selectedDate!) == key;

    // Colors
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

    // indicator config (very small and fixed to avoid overflow)
    final int maxDots = 3;
    final int dotsToShow = math.min(events.length, maxDots);
    final int overflow = events.length - dotsToShow;
    const double indicatorDotSize = 8.0;
    const double indicatorSpacing = 4.0;
    const double bottomPadding = 6.0; // space from bottom for indicators
    const double topPadding = 6.0; // space from top for day number

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
                  // TOP: day number
                  Positioned(
                    top: topPadding,
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

                  // BOTTOM: event indicators row (dots + optional +N)
                  if (events.isNotEmpty)
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: bottomPadding,
                      child: Row(
                        children: [
                          // Dots
                          for (int i = 0; i < dotsToShow; i++) ...[
                            Container(
                              width: indicatorDotSize,
                              height: indicatorDotSize,
                              margin: const EdgeInsets.only(right: indicatorSpacing),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : AppStyles.primary,
                                borderRadius:
                                    BorderRadius.circular(indicatorDotSize / 2),
                                border: isSelected
                                    ? Border.all(color: Colors.white)
                                    : null,
                              ),
                            ),
                          ],

                          // Overflow badge
                          if (overflow > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : AppStyles.primary.withOpacity(0.18),
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

  Widget _eventDots(List<Event> events, {bool highlighted = false}) {
    int show = events.length > 3 ? 3 : events.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(show, (i) {
        final opacity = highlighted ? 1.0 : (0.8 - i * 0.2).clamp(0.2, 1.0);
        final height = highlighted ? 8.0 : 6.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 3),
          height: height,
          width: 24,
          decoration: BoxDecoration(
            color: AppStyles.primary.withAlpha((opacity * 255).round()),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  // ------------------ DAY EVENT LIST ------------------
  void _openDayEvents(DateTime date) {
    final key = _dateKey(date);
    final events = _events[key] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // allow custom backdrop
      builder: (_) {
        // Use BackdropFilter to blur underlying calendar and a dim overlay
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
          child: Container(
            // semi-transparent dim layer so the sheet "pops"
            color: Colors.black.withOpacity(0.18),
            child: DraggableScrollableSheet(
              initialChildSize: 0.5,
              maxChildSize: 0.9,
              builder: (context, controller) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.98),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // header with back button that closes the sheet
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () {
                              Navigator.pop(context); // closes the sheet
                            },
                          ),

                          Expanded(
                            child: Text(_dateLabel(date),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              Navigator.pop(context);
                              _showAddEventDialog(context, date);
                            },
                          )
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
                                    subtitle: Text(
                                        "${_timeLabel(e.start)} • ${e.type} • ${e.status}"),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      color: AppStyles.iconButtonColor,
                                      onPressed: () {
                                        setState(() {
                                          _events[key]?.removeAt(index);
                                          if ((_events[key]?.isEmpty ?? true)) {
                                            _events.remove(key);
                                          }
                                        });
                                        Navigator.pop(context);
                                        // reopen so UI updates
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
          ),
        );
      },
    );
  }

  // ------------------ ADD / EDIT EVENT BOTTOM SHEET ------------------
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
      backgroundColor: Colors.transparent, // make transparent so we can blur/dim
      builder: (sheetContext) {
        final mq = MediaQuery.of(sheetContext);

        return Padding(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
            child: Container(
              color: Colors.black.withOpacity(0.18), // dim layer
              child: DraggableScrollableSheet(
                initialChildSize: 0.55,
                minChildSize: 0.35,
                maxChildSize: 0.95,
                expand: false,
                builder: (contextDS, controller) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.98),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      controller: controller,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: StatefulBuilder(
                          builder: (contextSB, setStateSB) {
                            return Form(
                              key: formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // HEADER
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => Navigator.pop(sheetContext),
                                      ),
                                      Expanded(
                                        child: Text(
                                          existing == null ? "Add Event" : "Edit Event",
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      // spacer so title stays centered
                                      const SizedBox(width: 48),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  // TITLE
                                  TextFormField(
                                    initialValue: title,
                                    decoration: const InputDecoration(
                                      labelText: "Title",
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (v) =>
                                        v == null || v.isEmpty ? "Please enter a title" : null,
                                    onChanged: (v) => title = v,
                                  ),

                                  const SizedBox(height: 12),

                                  // DATE PICKER
                                  InkWell(
                                    onTap: () async {
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
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: "Start",
                                        border: OutlineInputBorder(),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              "${_dateLabel(start)}  ${_timeLabel(start)}",
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const Icon(Icons.calendar_today, color: Colors.black54),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // TYPE + STATUS
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
                                          decoration: const InputDecoration(
                                            labelText: "Type",
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: status,
                                          isExpanded: true,
                                          items: ["Not Started", "In Progress", "Completed"]
                                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                              .toList(),
                                          onChanged: (v) {
                                            if (v != null) setStateSB(() => status = v);
                                          },
                                          decoration: const InputDecoration(
                                            labelText: "Status",
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  // LOCATION
                                  TextFormField(
                                    initialValue: location,
                                    decoration: const InputDecoration(
                                      labelText: "Location",
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (v) => location = v,
                                  ),

                                  const SizedBox(height: 12),

                                  // DESCRIPTION
                                  TextFormField(
                                    initialValue: description,
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                      labelText: "Description",
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (v) => description = v,
                                  ),

                                  const SizedBox(height: 16),

                                  // ACTION BUTTONS (consistent design)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(sheetContext),
                                        child: const Text("Cancel"),
                                        style: AppStyles.textActionStyle(),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: AppStyles.elevatedPrimaryStyle(minWidth: 92),
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
                                              _selectedDate =
                                                  DateTime(start.year, start.month, start.day);
                                            });

                                            Navigator.pop(sheetContext);
                                          }
                                        },
                                        child: const Text("Save"),
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
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
