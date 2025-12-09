// lib/user/user_calendar.dart
// Enhanced read-only calendar for regular users with improved design

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

  bool _showTasks = true;
  bool _showMeetings = true;
  bool _showCompleted = true;
  bool _showPending = true;

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

  List<Event> _getFilteredEvents(List<Event> events) {
    return events.where((event) {
      if (event.source == 'task' && !_showTasks) return false;
      if (event.source == 'meeting' && !_showMeetings) return false;
      final isCompleted = event.status.toLowerCase().contains('complete');
      if (isCompleted && !_showCompleted) return false;
      if (!isCompleted && !_showPending) return false;
      return true;
    }).toList();
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
            // Skip
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
          // Skip
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
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _goToToday() async {
    setState(() {
      _displayMonth = DateTime.now();
      _selectedDate = DateTime.now();
    });

    final todayKey = _dateKey(DateTime.now());
    final allEvents = _events[todayKey] ?? [];
    final filteredEvents = _getFilteredEvents(allEvents);

    if (filteredEvents.isNotEmpty) {
      _openDayEvents(DateTime.now());
    } else {
      _showSnack('No events today');
    }
  }

  Future<void> _showCalendarFilters() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Calendar Filters',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [primary, primaryDark]),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _FilterOption(
              icon: Icons.task_alt,
              label: 'Show Tasks',
              value: _showTasks,
              onChanged: (val) => setState(() => _showTasks = val),
            ),
            _FilterOption(
              icon: Icons.event,
              label: 'Show Meetings',
              value: _showMeetings,
              onChanged: (val) => setState(() => _showMeetings = val),
            ),
            _FilterOption(
              icon: Icons.check_circle,
              label: 'Show Completed',
              value: _showCompleted,
              onChanged: (val) => setState(() => _showCompleted = val),
            ),
            _FilterOption(
              icon: Icons.pending,
              label: 'Show Pending',
              value: _showPending,
              onChanged: (val) => setState(() => _showPending = val),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GradientButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {});
                      _showSnack('Filters applied');
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEventDetails(Event event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    event.source == 'task' ? Icons.task : Icons.event,
                    color: primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        event.source.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _DetailRow(
              icon: Icons.access_time,
              label: 'Time',
              value: _timeLabel(event.start),
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.category,
              label: 'Type',
              value: event.type,
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.flag,
              label: 'Status',
              value: event.status,
              valueColor: event.status.toLowerCase().contains('complete')
                  ? Colors.green
                  : Colors.orange,
            ),
            if (event.location.isNotEmpty) ...[
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.location_on,
                label: 'Location',
                value: event.location,
              ),
            ],
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.notes,
                label: 'Description',
                value: event.description,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: _GradientButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDayEvents(DateTime date) {
    final key = _dateKey(date);
    final allEvents = _events[key] ?? [];
    final events = _getFilteredEvents(allEvents);

    if (events.isEmpty) {
      _showSnack('No events on ${_dateLabel(date)}');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event, color: Colors.white, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _dateLabel(date),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${events.length} event${events.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                itemBuilder: (context, i) => _EventCard(
                  event: events[i],
                  onTap: () {
                    Navigator.pop(context);
                    _showEventDetails(events[i]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: RefreshIndicator(
        onRefresh: _refreshEvents,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                const SizedBox(height: 8),
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: _showCalendarFilters,
            heroTag: 'filter',
            mini: true,
            backgroundColor: Colors.white,
            foregroundColor: primary,
            child: const Icon(Icons.filter_list),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            onPressed: _goToToday,
            heroTag: 'today',
            backgroundColor: primary,
            child: const Icon(Icons.today),
          ),
        ],
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
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
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
      padding: const EdgeInsets.all(4),
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
    final allEvents = _events[key] ?? [];
    final events = _getFilteredEvents(allEvents);
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
      padding: const EdgeInsets.all(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() => _selectedDate = date);
          if (events.isNotEmpty) {
            _openDayEvents(date);
          } else {
            _showSnack('No events on ${_dateLabel(date)}');
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: border,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              if (hasEvents) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...List.generate(
                      dotsToShow,
                      (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    if (overflow > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 2),
                        child: Text(
                          '+$overflow',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== HELPER WIDGETS ====================

class _GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;

  const _GradientButton({
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_UserCalendarPageState.primary, _UserCalendarPageState.primaryDark],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FilterOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        secondary: Icon(icon, color: _UserCalendarPageState.primary),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        activeColor: _UserCalendarPageState.primary,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const _EventCard({
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = event.status.toLowerCase().contains('complete');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _UserCalendarPageState.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  event.source == 'task' ? Icons.task : Icons.event,
                  color: _UserCalendarPageState.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('h:mm a').format(event.start),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            event.status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isCompleted ? Colors.green : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}