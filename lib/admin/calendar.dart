import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import '/services/api_service.dart';

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

  String get taskId => id.replaceFirst('task_', '');
  String get meetingId => id.replaceFirst('meeting_', '');
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with SingleTickerProviderStateMixin {
  DateTime _displayMonth = DateTime.now();
  DateTime? _selectedDate;
  final Map<String, List<Event>> _events = {};
  final DateFormat _labelFormat = DateFormat('EEE, MMM d, yyyy');

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _fabExpanded = false;
  late AnimationController _fabController;

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
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  String _dateKey(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String _monthLabel(DateTime d) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
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

  void _toggleFAB() {
    setState(() {
      _fabExpanded = !_fabExpanded;
      if (_fabExpanded) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
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

  String _generateCSV(List<Event> events) {
    final buffer = StringBuffer();
    buffer.writeln('Title,Type,Date,Time,Status,Location,Description,Source');
    for (var event in events) {
      buffer.writeln('"${event.title}","${event.type}","${_dateLabel(event.start)}","${_timeLabel(event.start)}","${event.status}","${event.location}","${event.description}","${event.source}"');
    }
    return buffer.toString();
  }

  String _generateICalendar(List<Event> events) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//StudyBuddy//Calendar Export//EN');
    for (var event in events) {
      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:${event.id}@studybuddy.app');
      buffer.writeln('DTSTAMP:${_formatICalDateTime(DateTime.now())}');
      buffer.writeln('DTSTART:${_formatICalDateTime(event.start)}');
      buffer.writeln('SUMMARY:${event.title}');
      buffer.writeln('DESCRIPTION:${event.description}');
      if (event.location.isNotEmpty) buffer.writeln('LOCATION:${event.location}');
      buffer.writeln('STATUS:${event.status.toUpperCase()}');
      buffer.writeln('END:VEVENT');
    }
    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  String _formatICalDateTime(DateTime dt) {
    return dt.toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.')[0] + 'Z';
  }

  // ------------------ Part 2 & 3 methods ------------------

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

  Future<void> _goToToday() async {
    _toggleFAB();
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

  Future<void> _exportCalendar() async {
    _toggleFAB();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
            const Text('Export Calendar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Choose export format:', style: TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 16),
            _ExportOption(
              icon: Icons.table_chart,
              title: 'CSV Format',
              subtitle: 'Compatible with Excel and Google Sheets',
              onTap: () {
                Navigator.pop(context);
                _performExport('csv');
              },
            ),
            const SizedBox(height: 12),
            _ExportOption(
              icon: Icons.picture_as_pdf,
              title: 'PDF Format',
              subtitle: 'Printable document',
              onTap: () {
                Navigator.pop(context);
                _performExport('pdf');
              },
            ),
            const SizedBox(height: 12),
            _ExportOption(
              icon: Icons.calendar_today,
              title: 'iCal Format',
              subtitle: 'Import to other calendar apps',
              onTap: () {
                Navigator.pop(context);
                _performExport('ical');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performExport(String format) async {
    _showSnack('Preparing $format export...');

    final allEvents = <Event>[];
    for (var eventList in _events.values) {
      allEvents.addAll(eventList);
    }

    if (allEvents.isEmpty) {
      _showSnack('No events to export');
      return;
    }

    allEvents.sort((a, b) => a.start.compareTo(b.start));

    switch (format) {
      case 'csv':
        _generateCSV(allEvents);
        break;
      case 'pdf':
        _showSnack('PDF export coming soon');
        return;
      case 'ical':
        _generateICalendar(allEvents);
        break;
    }

    _showSnack('Exported ${allEvents.length} events as $format');
  }

  Future<void> _showCalendarFilters() async {
    _toggleFAB();

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
                  child: Text('Calendar Filters', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
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

  Future<void> _quickAddTask() async {
    _toggleFAB();

    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime selectedDate = _selectedDate ?? DateTime.now();
    String selectedType = 'assignment';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_task, color: primary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text('Quick Add Task', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Task Title',
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Task Type',
                    prefixIcon: const Icon(Icons.category),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'assignment', child: Text('Assignment')),
                    DropdownMenuItem(value: 'quiz', child: Text('Quiz')),
                    DropdownMenuItem(value: 'exam', child: Text('Exam')),
                    DropdownMenuItem(value: 'project', child: Text('Project')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedType = val);
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setModalState(() => selectedDate = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Due Date',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_dateLabel(selectedDate)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    prefixIcon: const Icon(Icons.notes),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GradientButton(
                        onPressed: () async {
                          if (titleController.text.trim().isEmpty) {
                            _showSnack('Please enter a task title');
                            return;
                          }

                          Navigator.pop(context);

                          final result = await ApiService.createTask({
                            'title': titleController.text.trim(),
                            'type': selectedType,
                            'due': selectedDate.toIso8601String(),
                            'notes': descController.text.trim(),
                            'completed': false,
                          });

                          if (result['success'] == true) {
                            await _refreshEvents();
                            _showSnack('Task created successfully');
                          } else {
                            _showSnack(result['message'] ?? 'Failed to create task');
                          }
                        },
                        child: const Text('Create Task'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _quickAddMeeting() async {
    _toggleFAB();

    final titleController = TextEditingController();
    final purposeController = TextEditingController();
    final locationController = TextEditingController();
    final linkController = TextEditingController();
    DateTime selectedDate = _selectedDate ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    String selectedType = 'team';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
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
                        child: const Icon(Icons.video_call, color: primary, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text('Quick Add Meeting', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Meeting Title',
                      prefixIcon: const Icon(Icons.title),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: InputDecoration(
                      labelText: 'Meeting Type',
                      prefixIcon: const Icon(Icons.category),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'team', child: Text('Team Meeting')),
                      DropdownMenuItem(value: 'client', child: Text('Client Meeting')),
                      DropdownMenuItem(value: 'planning', child: Text('Planning')),
                      DropdownMenuItem(value: 'review', child: Text('Review')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) setModalState(() => selectedDate = picked);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Date',
                              prefixIcon: const Icon(Icons.calendar_today),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(DateFormat('MMM d, yyyy').format(selectedDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(context: context, initialTime: selectedTime);
                            if (picked != null) setModalState(() => selectedTime = picked);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Time',
                              prefixIcon: const Icon(Icons.access_time),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(selectedTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: locationController,
                    decoration: InputDecoration(
                      labelText: 'Location (Optional)',
                      prefixIcon: const Icon(Icons.location_on),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: linkController,
                    decoration: InputDecoration(
                      labelText: 'Meeting Link (Optional)',
                      prefixIcon: const Icon(Icons.link),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: purposeController,
                    decoration: InputDecoration(
                      labelText: 'Purpose (Optional)',
                      prefixIcon: const Icon(Icons.notes),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _GradientButton(
                          onPressed: () async {
                            if (titleController.text.trim().isEmpty) {
                              _showSnack('Please enter a meeting title');
                              return;
                            }

                            Navigator.pop(context);

                            final meetingDateTime = DateTime(
                              selectedDate.year,
                              selectedDate.month,
                              selectedDate.day,
                              selectedTime.hour,
                              selectedTime.minute,
                            );

                            final result = await ApiService.createMeeting({
                              'title': titleController.text.trim(),
                              'type': selectedType,
                              'datetime': meetingDateTime.toIso8601String(),
                              'location': locationController.text.trim(),
                              'meetLink': linkController.text.trim(),
                              'purpose': purposeController.text.trim(),
                              'attendees': [],
                            });

                            if (result['success'] == true) {
                              await _refreshEvents();
                              _showSnack('Meeting created successfully');
                            } else {
                              _showSnack(result['message'] ?? 'Failed to create meeting');
                            }
                          },
                          child: const Text('Create Meeting'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteEvent(Event event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      Map<String, dynamic> result;
      if (event.source == 'task') {
        result = await ApiService.deleteTask(event.taskId);
      } else {
        result = await ApiService.deleteMeeting(event.meetingId);
      }

      if (result['success'] == true) {
        await _refreshEvents();
        if (mounted) {
          _showSnack('${event.source == 'task' ? 'Task' : 'Meeting'} deleted');
        }
      } else {
        if (mounted) {
          _showSnack(result['message'] ?? 'Failed to delete');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Error deleting: $e');
      }
    }
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
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _deleteEvent(event);
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GradientButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (event.source == 'task') {
                        Navigator.pushNamed(context, '/planner').then((_) => _refreshEvents());
                      } else {
                        Navigator.pushNamed(context, '/meetings').then((_) => _refreshEvents());
                      }
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
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

  Widget _buildSmartFAB() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedOpacity(
          opacity: _fabExpanded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: _fabExpanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SmallFAB(
                    onPressed: _quickAddTask,
                    icon: Icons.add_task,
                    label: 'Add Task',
                    heroTag: 'add_task',
                  ),
                )
              : const SizedBox.shrink(),
        ),
        AnimatedOpacity(
          opacity: _fabExpanded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: _fabExpanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SmallFAB(
                    onPressed: _quickAddMeeting,
                    icon: Icons.video_call,
                    label: 'Add Meeting',
                    heroTag: 'add_meeting',
                  ),
                )
              : const SizedBox.shrink(),
        ),
        AnimatedOpacity(
          opacity: _fabExpanded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: _fabExpanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SmallFAB(
                    onPressed: _exportCalendar,
                    icon: Icons.download,
                    label: 'Export',
                    heroTag: 'export',
                  ),
                )
              : const SizedBox.shrink(),
        ),
        AnimatedOpacity(
          opacity: _fabExpanded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: _fabExpanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SmallFAB(
                    onPressed: _goToToday,
                    icon: Icons.today,
                    label: 'Today',
                    heroTag: 'today',
                  ),
                )
              : const SizedBox.shrink(),
        ),
        AnimatedOpacity(
          opacity: _fabExpanded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: _fabExpanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SmallFAB(
                    onPressed: _showCalendarFilters,
                    icon: Icons.filter_list,
                    label: 'Filters',
                    heroTag: 'filters',
                  ),
                )
              : const SizedBox.shrink(),
        ),
        FloatingActionButton(
          onPressed: _toggleFAB,
          backgroundColor: primary,
          heroTag: 'main',
          child: AnimatedRotation(
            turns: _fabExpanded ? 0.125 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(_fabExpanded ? Icons.close : Icons.add),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        elevation: 0,
        title: const Text('Calendar', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isRefreshing ? Icons.hourglass_empty : Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshEvents,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshEvents,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
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
          if (_fabExpanded)
            GestureDetector(
              onTap: _toggleFAB,
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildSmartFAB(),
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
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
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

class _SmallFAB extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final String heroTag;

  const _SmallFAB({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      heroTag: heroTag,
      backgroundColor: Colors.white,
      foregroundColor: _CalendarPageState.primary,
      elevation: 4,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

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
              colors: [_CalendarPageState.primary, _CalendarPageState.primaryDark],
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
        secondary: Icon(icon, color: _CalendarPageState.primary),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        activeColor: _CalendarPageState.primary,
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
                  color: _CalendarPageState.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  event.source == 'task' ? Icons.task : Icons.event,
                  color: _CalendarPageState.primary,
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

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ExportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _CalendarPageState.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _CalendarPageState.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
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
