// lib/user/user_calendar.dart
// Read-only calendar for regular users — AppBar removed, in-body header kept, FAB removed

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class Event {
  final String id;
  final String title;
  final DateTime start;
  final String type;
  final String status;
  final String location;
  final String description;
  final String source;
  final Map<String, dynamic>? rawData;

  Event({
    required this.id,
    required this.title,
    required this.start,
    required this.type,
    required this.status,
    this.location = '',
    this.description = '',
    this.source = 'task',
    this.rawData,
  });

  factory Event.fromTask(Map<String, dynamic> task) {
    DateTime startDate;
    try {
      startDate = DateTime.parse(task['due'] ?? DateTime.now().toIso8601String());
    } catch (e) {
      startDate = DateTime.now();
    }

    return Event(
      id: 'task_${task['id']}',
      title: task['title'] ?? 'Untitled Task',
      start: startDate,
      type: task['type'] ?? 'assignment',
      status: task['completed'] == true ? 'Completed' : 'Pending',
      location: '',
      description: task['notes'] ?? task['desc'] ?? '',
      source: 'task',
      rawData: task,
    );
  }

  factory Event.fromMeeting(Map<String, dynamic> meeting) {
    DateTime startDate;
    try {
      startDate = DateTime.parse(meeting['datetime']);
    } catch (e) {
      startDate = DateTime.now();
    }

    return Event(
      id: 'meeting_${meeting['id']}',
      title: meeting['title'] ?? 'Untitled Meeting',
      start: startDate,
      type: meeting['type'] ?? 'meeting',
      status: meeting['status'] ?? 'Not Started',
      location: meeting['location'] ?? '',
      description: meeting['purpose'] ?? '',
      source: 'meeting',
      rawData: meeting,
    );
  }
}

class UserCalendarPage extends StatefulWidget {
  const UserCalendarPage({super.key});

  @override
  State<UserCalendarPage> createState() => _UserCalendarPageState();
}

class _UserCalendarPageState extends State<UserCalendarPage> {
  DateTime _displayMonth = DateTime.now();
  DateTime? _selectedDate;
  final Map<String, List<Event>> _events = {};
  final DateFormat _labelFormat = DateFormat('EEE, MMM d, yyyy');

  bool _isLoading = false;
  bool _isRefreshing = false;

  static const Color primary = Color(0xFF10B981);
  static const Color primaryDark = Color(0xFF059669);

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

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

  Future<void> _loadEvents() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final tasksData = await ApiService.getTasks();
      final meetingsData = await ApiService.getMeetings();

      if (!mounted) return;

      final Map<String, List<Event>> newEvents = {};

      for (var task in tasksData) {
        if (task['due'] != null && task['due'].toString().isNotEmpty) {
          try {
            final event = Event.fromTask(task);
            final key = _dateKey(event.start);
            newEvents.putIfAbsent(key, () => []);
            newEvents[key]!.add(event);
          } catch (e) {
            debugPrint('Error parsing task: $e');
          }
        }
      }

      for (var meeting in meetingsData) {
        try {
          final event = Event.fromMeeting(meeting);
          final key = _dateKey(event.start);
          newEvents.putIfAbsent(key, () => []);
          newEvents[key]!.add(event);
        } catch (e) {
          debugPrint('Error parsing meeting: $e');
        }
      }

      setState(() {
        _events.clear();
        _events.addAll(newEvents);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Failed to load events: $e');
    }
  }

  Future<void> _refreshEvents() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final tasksData = await ApiService.getTasks();
      final meetingsData = await ApiService.getMeetings();

      if (!mounted) return;

      final Map<String, List<Event>> newEvents = {};

      for (var task in tasksData) {
        if (task['due'] != null && task['due'].toString().isNotEmpty) {
          try {
            final event = Event.fromTask(task);
            final key = _dateKey(event.start);
            newEvents.putIfAbsent(key, () => []);
            newEvents[key]!.add(event);
          } catch (e) {
            // Silently skip invalid tasks during refresh
          }
        }
      }

      for (var meeting in meetingsData) {
        try {
          final event = Event.fromMeeting(meeting);
          final key = _dateKey(event.start);
          newEvents.putIfAbsent(key, () => []);
          newEvents[key]!.add(event);
        } catch (e) {
          // Silently skip invalid meetings during refresh
        }
      }

      setState(() {
        _events.clear();
        _events.addAll(newEvents);
        _isRefreshing = false;
      });

      _showSnack('Calendar refreshed');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRefreshing = false);
      _showSnack('Failed to refresh: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const padding = 12.0;

    return Scaffold(
      extendBody: true,
      // AppBar removed — in-body header is kept below, floating button removed
      body: RefreshIndicator(
        onRefresh: _refreshEvents,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: padding),
            child: Column(
              children: [
                // keep the header chips (calendar overview) inside the body
                _headerRightChips(),
                const SizedBox(height: 12),
                _monthNavigator(),
                const SizedBox(height: 10),
                _weekLabels(),
                const SizedBox(height: 8),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _monthGrid(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerRightChips() {
    final today = DateTime.now();
    final todayLabel = DateFormat('EEE, MMM d').format(today);

    final now = DateTime.now();
    final weekEnd = now.add(const Duration(days: 7));
    final upcomingCount = _events.entries
        .expand((e) => e.value)
        .where((ev) =>
            ev.start.isAfter(now.subtract(const Duration(seconds: 1))) &&
            ev.start.isBefore(weekEnd.add(const Duration(seconds: 1))))
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Calendar Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: primary.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: primaryDark),
                    const SizedBox(width: 8),
                    Text(
                      todayLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_available, size: 14, color: primaryDark),
                    const SizedBox(width: 6),
                    Text(
                      '$upcomingCount upcoming',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _monthNavigator() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          color: primaryDark,
          onPressed: () {
            setState(() {
              _displayMonth = DateTime(
                _displayMonth.year,
                _displayMonth.month - 1,
                1,
              );
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
          color: primaryDark,
          onPressed: () {
            setState(() {
              _displayMonth = DateTime(
                _displayMonth.year,
                _displayMonth.month + 1,
                1,
              );
            });
          },
        ),
      ],
    );
  }

  Widget _weekLabels() {
    final labels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    return Row(
      children: labels
          .map((d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ))
          .toList(),
    );
  }

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
      bgColor = primary;
      textColor = Colors.white;
      border = Border.all(color: primaryDark, width: 1.5);
    } else if (hasEvents) {
      bgColor = primary.withOpacity(0.05);
      textColor = isToday ? primary : Colors.black87;
      border = Border.all(color: const Color(0xFFE8EAEF));
    } else if (isToday) {
      bgColor = primary.withOpacity(0.05);
      textColor = primary;
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
          setState(() => _selectedDate = date);
          _openDayEvents(date);
        },
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
                                color: isSelected ? Colors.white : primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          if (overflow > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : primary.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "+$overflow",
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: primaryDark,
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
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: events.isEmpty
                          ? const Center(
                              child: Text("No events for this day."),
                            )
                          : ListView.separated(
                              controller: controller,
                              itemBuilder: (context, index) {
                                final e = events[index];
                                return _buildEventTile(e);
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

  Widget _buildEventTile(Event event) {
    return ListTile(
      leading: Icon(
        event.source == 'task' ? Icons.task : Icons.event,
        color: primary,
      ),
      title: Text(event.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${_timeLabel(event.start)} • ${event.type}"),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: event.status.toLowerCase().contains('complete')
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  event.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: event.status.toLowerCase().contains('complete')
                        ? Colors.green[700]
                        : Colors.orange[700],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  event.source.toUpperCase(),
                  style: const TextStyle(fontSize: 10),
                ),
                backgroundColor: primary.withOpacity(0.1),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.visibility, color: primary),
      isThreeLine: true,
    );
  }
}
