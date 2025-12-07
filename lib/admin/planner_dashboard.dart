// lib/admin/planner_dashboard.dart
// Planner page — responsive segmented control with animated thumb, robust layout for narrow phones.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class Task {
  Task({
    required this.id,
    required this.title,
    this.desc = '',
    this.type = 'assignment',
    this.priority = 'medium',
    required this.dueDateIso,
    this.progress = 0,
    this.completed = false,
    required this.createdAtIso,
    this.course = '',
    List<String>? tags,
  }) : tags = tags ?? [];

  int id;
  String title;
  String desc;
  String type;
  String priority;
  String dueDateIso;
  int progress;
  bool completed;
  String createdAtIso;
  String course;
  List<String> tags;

  factory Task.fromMap(Map<String, dynamic> m) {
    final dynamic rawId = m['id'];
    final int id = rawId is int
        ? rawId
        : int.tryParse('$rawId') ?? DateTime.now().millisecondsSinceEpoch;

    final String title = (m['title'] ?? '').toString();
    final String desc = (m['desc'] ?? '').toString();
    final String type = (m['type'] ?? 'assignment').toString();
    final String priority = (m['priority'] ?? 'medium').toString();
    final String dueDateIso = (m['dueDateIso'] ?? m['dueDate'] ?? '').toString();
    final String createdAtIso =
        (m['createdAtIso'] ?? DateTime.now().toIso8601String()).toString();
    final String course = (m['course'] ?? '').toString();

    final dynamic rawProgress = m['progress'] ?? 0;
    int progress;
    if (rawProgress is int) {
      progress = rawProgress;
    } else if (rawProgress is double) {
      progress = rawProgress.toInt();
    } else {
      progress = int.tryParse('$rawProgress') ?? 0;
    }

    final dynamic rawCompleted = m['completed'] ?? false;
    bool completed;
    if (rawCompleted is bool) {
      completed = rawCompleted;
    } else if (rawCompleted is int) {
      completed = rawCompleted != 0;
    } else {
      final s = '$rawCompleted'.toLowerCase();
      completed = (s == 'true' || s == '1');
    }

    List<String> tags = [];
    if (m.containsKey('tags')) {
      final rawTags = m['tags'];
      if (rawTags is List) {
        tags = rawTags.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      } else if (rawTags is String) {
        tags = rawTags.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
    }

    return Task(
      id: id,
      title: title,
      desc: desc,
      type: type,
      priority: priority,
      dueDateIso: dueDateIso,
      progress: progress.clamp(0, 100),
      completed: completed,
      createdAtIso: createdAtIso,
      course: course,
      tags: tags,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'desc': desc,
      'type': type,
      'priority': priority,
      'dueDateIso': dueDateIso,
      'progress': progress,
      'completed': completed,
      'createdAtIso': createdAtIso,
      'course': course,
      'tags': tags,
    };
  }
}

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key});

  @override
  State<PlannerPage> createState() => _PlannerHomePage();
}

enum SortBy { due, priority, created }

class _PlannerHomePage extends State<PlannerPage> with TickerProviderStateMixin {
  static const storageKey = 'planner_tasks_v2';

  final List<Task> tasks = [];
  final List<Map<String, dynamic>> pendingDeletes = []; // store snapshot + expiresAt
  String currentTab = 'all';
  String search = '';
  bool timelineView = true;
  SortBy sortBy = SortBy.due;
  late final DateFormat dateFormatter;

  // controllers for add/edit
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleCtl = TextEditingController();
  final TextEditingController _descCtl = TextEditingController();
  final TextEditingController _dueDateCtl = TextEditingController();
  String _type = 'assignment';
  String _priority = 'medium';
  int _progress = 0; // kept as internal state but hidden from UI
  bool _completed = false;
  int? _editingId;
  DateTime? _pickedDate;

  // used to position thumb via measured button keys
  final Map<String, GlobalKey> _segKeys = {
    'all': GlobalKey(),
    'pending': GlobalKey(),
    'completed': GlobalKey(),
    'high': GlobalKey(),
  };

  // Emerald for the active thumb
  static const Color segEmerald = Color(0xFF059669);
  static const Color segEmeraldDark = Color(0xFF047857);

  // show-more for tasks
  final int _maxVisibleTasks = 2;
  bool _showMoreTasks = false;

  @override
  void initState() {
    super.initState();
    dateFormatter = DateFormat.yMMMEd();
    _loadFromStorage();
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    _dueDateCtl.dispose();
    super.dispose();
  }

  Future<void> _loadFromStorage() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(storageKey);
    if (raw == null) {
      // populate sample
      final now = DateTime.now();
      final sample = [
        Task(
            id: 1,
            title: 'Math Assignment #5',
            desc: 'Finish problems 1-10',
            type: 'assignment',
            priority: 'high',
            dueDateIso: DateTime(now.year, now.month, now.day + 2).toIso8601String(),
            progress: 20,
            completed: false,
            createdAtIso: now.toIso8601String(),
            course: 'MATH101',
            tags: ['homework', 'chapter5']),
        Task(
            id: 2,
            title: 'Chemistry Lab Report',
            desc: 'Analyze the titration data',
            type: 'project',
            priority: 'medium',
            dueDateIso: DateTime(now.year, now.month, now.day + 5).toIso8601String(),
            progress: 0,
            completed: false,
            createdAtIso: now.toIso8601String(),
            course: 'CHEM201',
            tags: ['lab']),
        Task(
            id: 3,
            title: 'History Exam Revision',
            desc: 'Read chapters 4-6',
            type: 'study',
            priority: 'low',
            dueDateIso: DateTime(now.year, now.month, now.day - 3).toIso8601String(),
            progress: 80,
            completed: true,
            createdAtIso: now.toIso8601String(),
            course: 'HIST110',
            tags: ['revision', 'exam']),
        Task(
            id: 4,
            title: 'Physics Homework',
            desc: 'Chapter 7 problems',
            type: 'assignment',
            priority: 'medium',
            dueDateIso: DateTime(now.year, now.month, now.day + 1).toIso8601String(),
            progress: 10,
            completed: false,
            createdAtIso: now.toIso8601String(),
            course: 'PHYS101',
            tags: ['homework']),
        Task(
            id: 5,
            title: 'English Essay',
            desc: 'Draft introduction',
            type: 'assignment',
            priority: 'low',
            dueDateIso: DateTime(now.year, now.month, now.day + 6).toIso8601String(),
            progress: 0,
            completed: false,
            createdAtIso: now.toIso8601String(),
            course: 'ENG201',
            tags: ['essay']),
      ];
      tasks.addAll(sample);
      await _saveToStorage();
      setState(() {});
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        tasks.clear();
        for (final e in decoded) {
          if (e is Map<String, dynamic>) {
            tasks.add(Task.fromMap(e));
          } else if (e is Map) {
            final map = <String, dynamic>{};
            e.forEach((k, v) => map['${k ?? ''}'] = v);
            tasks.add(Task.fromMap(map));
          }
        }
      }
    } catch (_) {
      // ignore and keep empty
    }
    setState(() {});
  }

  Future<void> _saveToStorage() async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(tasks.map((t) => t.toMap()).toList());
    await sp.setString(storageKey, raw);
  }

  int daysDiff(String? iso) {
    if (iso == null || iso.isEmpty) return 9999;
    DateTime? d = DateTime.tryParse(iso);
    if (d == null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(iso)) {
      d = DateTime.tryParse('${iso}T00:00:00');
    }
    if (d == null) return 9999;
    final today = DateTime.now();
    final td = DateTime(today.year, today.month, today.day);
    final target = DateTime(d.year, d.month, d.day);
    return target.difference(td).inDays;
  }

  String fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return 'TBD';
    final dt = DateTime(d.year, d.month, d.day);
    return dateFormatter.format(dt);
  }

  List<Task> getFilteredSorted() {
    final q = search.trim().toLowerCase();
    var list = tasks.where((t) {
      final matchesSearch = q.isEmpty ||
          t.title.toLowerCase().contains(q) ||
          t.desc.toLowerCase().contains(q) ||
          t.course.toLowerCase().contains(q) ||
          t.tags.any((tag) => tag.toLowerCase().contains(q));
      if (!matchesSearch) return false;
      if (currentTab == 'pending') return !t.completed;
      if (currentTab == 'completed') return t.completed;
      if (currentTab == 'high') return t.priority == 'high';
      return true;
    }).toList();

    if (sortBy == SortBy.due) {
      list.sort((a, b) {
        final da = DateTime.tryParse(a.dueDateIso);
        final db = DateTime.tryParse(b.dueDateIso);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    } else if (sortBy == SortBy.priority) {
      final order = {'high': 0, 'medium': 1, 'low': 2};
      list.sort((a, b) => (order[a.priority] ?? 3) - (order[b.priority] ?? 3));
    } else if (sortBy == SortBy.created) {
      list.sort((a, b) {
        final pa = DateTime.tryParse(a.createdAtIso);
        final pb = DateTime.tryParse(b.createdAtIso);
        if (pa == null && pb == null) return 0;
        if (pa == null) return 1;
        if (pb == null) return -1;
        return pb.compareTo(pa);
      });
    }

    return list;
  }

  Map<String, int> computeStats() {
    final pending = tasks.where((t) => !t.completed).length;
    final completed = tasks.where((t) => t.completed).length;
    final high = tasks.where((t) => t.priority == 'high').length;
    final in7 = DateTime.now().add(const Duration(days: 7));
    final dueWeek = tasks.where((t) {
      try {
        final d = DateTime.tryParse(t.dueDateIso);
        if (d == null) return false;
        final dt = DateTime(d.year, d.month, d.day);
        final today = DateTime.now();
        final t7 = DateTime(in7.year, in7.month, in7.day);
        return dt.isAfter(DateTime(today.year, today.month, today.day - 1)) &&
            (dt.isBefore(t7.add(const Duration(days: 1))));
      } catch (_) {
        return false;
      }
    }).length;
    final avg = tasks.isEmpty ? 0 : (tasks.map((t) => t.progress).reduce((a, b) => a + b) ~/ tasks.length);
    final overdue = tasks.where((t) {
      final d = daysDiff(t.dueDateIso);
      return d < 0 && !t.completed;
    }).length;

    return {
      'pending': pending,
      'completed': completed,
      'high': high,
      'dueWeek': dueWeek,
      'avg': avg,
      'overdue': overdue,
    };
  }

  Future<void> _openAddDialog({Task? edit}) async {
    _editingId = edit?.id;
    if (edit != null) {
      _titleCtl.text = edit.title;
      _descCtl.text = edit.desc;
      _type = edit.type;
      _priority = edit.priority;
      _progress = edit.progress;
      _completed = edit.completed;
      _pickedDate = DateTime.tryParse(edit.dueDateIso);
      _dueDateCtl.text = _pickedDate == null ? '' : DateFormat('yyyy-MM-dd').format(_pickedDate!);
    } else {
      _editingId = null;
      _titleCtl.clear();
      _descCtl.clear();
      _type = 'assignment';
      _priority = 'medium';
      _progress = 0;
      _completed = false;
      _pickedDate = null;
      _dueDateCtl.clear();
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // Use Padding to let sheet grow above keyboard when it appears
        return AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF7F3FA), // subtle paper-like background similar to reference
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // top bar: title + circular close
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _editingId == null ? 'Add Task' : 'Edit Task',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                          ),
                          // circular close in green (like reference)
                          InkWell(
                            onTap: () => Navigator.of(ctx).pop(),
                            borderRadius: BorderRadius.circular(28),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: Color(0xFF059669),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Form
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _titleCtl,
                              decoration: const InputDecoration(
                                labelText: 'Title',
                                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),

                            // type + pick date/time button row
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _type,
                                    decoration: const InputDecoration(
                                      labelText: 'Type',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'assignment', child: Text('Assignment')),
                                      DropdownMenuItem(value: 'study', child: Text('Study')),
                                      DropdownMenuItem(value: 'project', child: Text('Project')),
                                      DropdownMenuItem(value: 'exam', child: Text('Exam')),
                                    ],
                                    onChanged: (v) => setState(() => _type = v ?? 'assignment'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Pick date & time pill
                                SizedBox(
                                  width: 160,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final now = DateTime.now();
                                      final initial = _pickedDate ?? now;
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: initial,
                                        firstDate: DateTime(now.year - 5),
                                        lastDate: DateTime(now.year + 5),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _pickedDate = DateTime(picked.year, picked.month, picked.day);
                                          _dueDateCtl.text = DateFormat('yyyy-MM-dd').format(_pickedDate!);
                                        });
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: const Color(0xFF059669),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.calendar_today, size: 16),
                                    label: Text(_dueDateCtl.text.isEmpty ? 'Pick date' : _dueDateCtl.text, style: const TextStyle(fontSize: 13)),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Priority + (placeholder for spacing)
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _priority,
                                    decoration: const InputDecoration(
                                      labelText: 'Priority',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'low', child: Text('Low')),
                                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                                      DropdownMenuItem(value: 'high', child: Text('High')),
                                    ],
                                    onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // keep layout stable: visually small helper container (matches ref spacing)
                                SizedBox(width: 80, child: Container()),
                              ],
                            ),

                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _descCtl,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              maxLines: 4,
                            ),
                            const SizedBox(height: 12),

                            // Mark completed (compact)
                            Row(
                              children: [
                                Checkbox(value: _completed, onChanged: (v) => setState(() => _completed = v ?? false)),
                                const SizedBox(width: 8),
                                const Text('Mark completed', style: TextStyle(fontWeight: FontWeight.w700)),
                              ],
                            ),

                            const SizedBox(height: 18),

                            // Bottom action row: Cancel + Save (green pill)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (!_formKey.currentState!.validate()) return;
                                      if (_pickedDate == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please select a due date')),
                                        );
                                        return;
                                      }

                                      final nowIso = DateTime.now().toIso8601String();

                                      if (_editingId != null) {
                                        final idx = tasks.indexWhere((t) => t.id == _editingId);
                                        if (idx != -1) {
                                          tasks[idx] = Task(
                                            id: _editingId!,
                                            title: _titleCtl.text.trim(),
                                            desc: _descCtl.text.trim(),
                                            type: _type,
                                            priority: _priority,
                                            dueDateIso: DateTime(_pickedDate!.year, _pickedDate!.month, _pickedDate!.day).toIso8601String(),
                                            progress: _progress,
                                            completed: _completed,
                                            createdAtIso: tasks[idx].createdAtIso,
                                            course: '',
                                            tags: [],
                                          );
                                        }
                                        _saveToStorage();
                                        Navigator.of(ctx).pop();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Task updated')),
                                        );
                                        setState(() {});
                                      } else {
                                        final id = DateTime.now().millisecondsSinceEpoch + (DateTime.now().microsecond % 1000);
                                        tasks.add(Task(
                                          id: id,
                                          title: _titleCtl.text.trim(),
                                          desc: _descCtl.text.trim(),
                                          type: _type,
                                          priority: _priority,
                                          dueDateIso: DateTime(_pickedDate!.year, _pickedDate!.month, _pickedDate!.day).toIso8601String(),
                                          progress: _progress,
                                          completed: _completed,
                                          createdAtIso: nowIso,
                                          course: '',
                                          tags: [],
                                        ));
                                        _saveToStorage();
                                        Navigator.of(ctx).pop();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Task added')),
                                        );
                                        setState(() {});
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF059669), // emerald green
                                      foregroundColor: Colors.white, // <-- TEXT COLOR WHITE
                                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                                      elevation: 6,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: Text(
                                      _editingId == null ? 'Add' : 'Save',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: Colors.white, // <-- MAKE SURE TEXT IS WHITE
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
      },
    );
  }

  Future<void> _confirmDelete(Task t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Delete task?'),
          content: const Text('Are you sure you want to delete this task? You can undo from the SnackBar for a short time.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete'))
          ],
        );
      },
    );
    if (ok != true) return;

    final snapshot = t.toMap();
    final pendingId = DateTime.now().microsecondsSinceEpoch;
    final expiresAt = DateTime.now().add(const Duration(seconds: 20));
    pendingDeletes.add({'pendingId': pendingId, 'snapshot': snapshot, 'expiresAt': expiresAt.toIso8601String()});

    tasks.removeWhere((x) => x.id == t.id);
    await _saveToStorage();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Deleted "${t.title}"'),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          final idx = pendingDeletes.indexWhere((p) => p['pendingId'] == pendingId);
          if (idx != -1) {
            final snap = pendingDeletes[idx]['snapshot'] as Map<String, dynamic>;
            final restored = Task.fromMap(snap);
            tasks.add(restored);
            await _saveToStorage();
            pendingDeletes.removeAt(idx);
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore successful')));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Undo expired')));
          }
        },
      ),
    ));

    setState(() {});
  }

  Future<void> _openRecoverModal() async {
    await showDialog(context: context, builder: (_) {
      final now = DateTime.now();
      final filtered = pendingDeletes.where((p) {
        final exp = DateTime.tryParse(p['expiresAt'] ?? '');
        if (exp == null) return false;
        return exp.isAfter(now);
      }).toList();

      return AlertDialog(
        title: const Text('Recently deleted (recoverable)'),
        content: SizedBox(
          width: double.maxFinite,
          child: filtered.isEmpty
              ? const Text('No recoverable deletes.')
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    final snapshot = Map<String, dynamic>.from(p['snapshot']);
                    final pendingId = p['pendingId'];
                    final expiresAt = DateTime.tryParse(p['expiresAt']) ?? DateTime.now();
                    final remaining = expiresAt.difference(DateTime.now()).inSeconds;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(snapshot['title'] ?? 'Task'),
                        subtitle: Text(snapshot['desc'] ?? ''),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Recoverable: ${remaining}s'),
                            const SizedBox(height: 8),
                            ElevatedButton(
                                onPressed: () async {
                                  final restored = Task.fromMap(snapshot);
                                  tasks.add(restored);
                                  await _saveToStorage();
                                  pendingDeletes.removeWhere((x) => x['pendingId'] == pendingId);
                                  setState(() {});
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore successful')));
                                },
                                child: const Text('Restore')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      );
    });
  }

  Future<void> _openStatsModal(String filter, String title) async {
    final all = tasks;
    List<Task> list = all;
    if (filter == 'pending') list = all.where((t) => !t.completed).toList();
    if (filter == 'completed') list = all.where((t) => t.completed).toList();
    if (filter == 'high') list = all.where((t) => t.priority == 'high').toList();
    if (filter == 'week') {
      final today = DateTime.now();
      final in7 = today.add(const Duration(days: 7));
      list = all.where((t) {
        final d = DateTime.tryParse(t.dueDateIso);
        if (d == null) return false;
        final dt = DateTime(d.year, d.month, d.day);
        return dt.isAfter(DateTime(today.year, today.month, today.day - 1)) && dt.isBefore(in7.add(const Duration(days: 1)));
      }).toList();
    }

    await showDialog(context: context, builder: (_) {
      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: list.isEmpty
              ? const Text('No tasks found.')
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final t = list[i];
                    return ListTile(
                      title: Text(t.title),
                      subtitle: Text('${fmtDate(t.dueDateIso)}'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      );
    });
  }

  /// Segmented control — tuned so all categories are visible on phone widths:
  /// - uses Expanded for even spacing when there's enough width
  /// - when space is tight uses Flexible + FittedBox so labels scale down instead of allowing horizontal scrolling
  Widget _segmentedControl() {
    final tabs = ['all', 'pending', 'completed', 'high'];

    return LayoutBuilder(builder: (context, constraints) {
      // request thumb update after layout
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateThumbPosition());

      final ultraCompact = constraints.maxWidth < 360; // phones ~360 width will use this
      final compact = !ultraCompact && constraints.maxWidth < 460;
      final hideThumb = constraints.maxWidth < 260; // very tiny: hide thumb to avoid occlusion

      final horizontalPadding = ultraCompact ? 6.0 : (compact ? 8.0 : 12.0);
      final verticalPadding = ultraCompact ? 4.0 : (compact ? 6.0 : 8.0);
      final fontSize = ultraCompact ? 11.0 : (compact ? 12.0 : 14.0);
      // reduce button min width so more pills can fit on narrow screens
      final minBtnWidth = ultraCompact ? 44.0 : (compact ? 56.0 : 72.0);

      final activeBg = segEmerald;
      final activeText = Colors.white;
      final inactiveText = segEmeraldDark;

      // compute whether we have enough width to show all tabs evenly
      final totalMinNeeded = (minBtnWidth * tabs.length) + (tabs.length - 1) * 4.0 + horizontalPadding * 2;
      final canFitEvenly = constraints.hasBoundedWidth && constraints.maxWidth >= totalMinNeeded;

      Widget buildButton(String t, {bool expanded = false}) {
        final label = t[0].toUpperCase() + t.substring(1);
        final active = t == currentTab;
        final Color btnBgColor = active ? activeBg : Colors.transparent;
        final labelColor = active ? activeText : inactiveText;

        final button = TextButton(
          key: _segKeys[t],
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
            backgroundColor: btnBgColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            foregroundColor: labelColor,
            textStyle: TextStyle(fontSize: fontSize, fontWeight: active ? FontWeight.w800 : FontWeight.w700),
          ),
          onPressed: () {
            setState(() {
              currentTab = t;
            });
            _updateThumbPosition();
          },
          child: Text(label, style: TextStyle(fontWeight: active ? FontWeight.w800 : FontWeight.w700, color: labelColor)),
        );

        if (expanded) {
          return Expanded(child: button);
        }

        // When space is tight, allow the label to shrink using FittedBox inside Flexible
        return Flexible(
          fit: FlexFit.tight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: 0, maxWidth: constraints.maxWidth),
              child: button,
            ),
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE6EDF3)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            alignment: Alignment.centerLeft,
            children: [
              if (!hideThumb)
                _AnimatedSegThumb(
                  keys: _segKeys,
                  activeKey: _segKeys[currentTab] ?? _segKeys['all']!,
                  colorA: segEmerald,
                  colorB: segEmeraldDark,
                  inflate: ultraCompact ? 2.5 : (compact ? 4.0 : 6.0),
                ),
              // If we can fit evenly, show Expanded children so tabs always visible and evenly sized.
              if (canFitEvenly)
                Row(
                  children: tabs.map((t) => buildButton(t, expanded: true)).toList(),
                )
              else
                // Fallback: show a single Row where each segment is Flexible + FittedBox (no horizontal scroll)
                Row(
                  children: tabs.map((t) => buildButton(t, expanded: false)).toList(),
                ),
            ],
          ),
        ),
      );
    });
  }

  void _updateThumbPosition() {
    // force a rebuild so AnimatedSegThumb measures again
    if (mounted) setState(() {});
  }

  Widget _taskCard(Task t) {
    final diff = daysDiff(t.dueDateIso);
    final overdue = diff < 0;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(children: [
          // Main content expands and will shrink before trailing actions
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                // Title constrained with ellipsis to avoid long single-line overflow
                Expanded(
                  child: Text(
                    t.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Date gets only intrinsic width (won't expand)
                Text(fmtDate(t.dueDateIso), style: TextStyle(color: Colors.grey[700], fontSize: 12)),
              ]),
              const SizedBox(height: 8),
              if (t.desc.isNotEmpty)
                Text(t.desc, style: TextStyle(color: Colors.grey[700]), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _typeChip(t.type),
                _priorityChip(t.priority),
                overdue ? Text('${diff.abs()}d overdue', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)) : Text('$diff d left', style: const TextStyle(color: Colors.grey)),
                ...t.tags.take(3).map((tag) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)), child: Text(tag, style: const TextStyle(fontSize: 12)))),
              ]),
              const SizedBox(height: 8),
            ]),
          ),
          const SizedBox(width: 12),
          // Trailing actions: fixed small width (no min width), arranged vertically so they can't push width.
          SizedBox(
            width: 56,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Meetings-style edit circle
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _openAddDialog(edit: t),
                    child: const Icon(Icons.edit, color: Colors.white, size: 18),
                  ),
                ),

                // increase gap so delete sits lower (matches reference more closely)
                const SizedBox(height: 18),

                // red trash slightly lower
                IconButton(
                  onPressed: () => _confirmDelete(t),
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                  tooltip: 'Delete',
                ),

                const SizedBox(height: 6),

                // compact checkbox so it won't expand layout
                Checkbox(
                  value: t.completed,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) async {
                    final idx = tasks.indexWhere((x) => x.id == t.id);
                    if (idx == -1) return;
                    tasks[idx].completed = v ?? false;
                    await _saveToStorage();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task updated')));
                  },
                ),
              ],
            ),
          )
        ]),
      ),
    );
  }

  Widget _typeChip(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Text(type, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _priorityChip(String p) {
    Color bg; Color text;
    switch (p) {
      case 'high':
        bg = const Color(0xFFFFF7F7);
        text = const Color(0xFFB91C1C);
        break;
      case 'medium':
        bg = const Color(0xFFFFF7ED);
        text = const Color(0xFFC2410C);
        break;
      default:
        bg = const Color(0xFFF0FDF4);
        text = const Color(0xFF065F46);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.transparent)),
      child: Text(p, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: text)),
    );
  }

  // SMALL pill button style used on bottom-right group
  ButtonStyle _smallPillStyle({bool filled = true}) {
    if (filled) {
      return ElevatedButton.styleFrom(
        backgroundColor: segEmerald,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(56, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        elevation: 6,
      );
    } else {
      return OutlinedButton.styleFrom(
        foregroundColor: segEmeraldDark,
        side: BorderSide(color: segEmerald.withOpacity(0.12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(56, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      );
    }
  }

  // small centered green pill used for Show more / Show less under tasks
  Widget _showMoreTasksPill() {
    final expanded = _showMoreTasks;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 6.0),
        child: InkWell(
          onTap: () => setState(() => _showMoreTasks = !_showMoreTasks),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [BoxShadow(color: const Color(0xFF059669).withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 6))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              // Animated rotation for icon to match budget_dashboard feel
              AnimatedRotation(
                turns: expanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                child: Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(expanded ? 'Show less' : 'Show more', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = getFilteredSorted();
    final stats = computeStats();
    final isWide = MediaQuery.of(context).size.width >= 1000;

    // We'll use a Stack so we can position the bottom-right pill group without changing layout.
    return Scaffold(
      // AppBar removed so back button and header do not appear
      body: SafeArea(
        child: Stack(
          children: [
            // Main scroll content
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 120), // extra bottom padding to avoid overlap with pills
              child: Column(children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE6EDF3))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Planner', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text('Organize your assignments and study schedule — timeline & board views.'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () => setState(() => timelineView = !timelineView),
                          style: _smallPillStyle(filled: true),
                          child: Text(timelineView ? 'Timeline View' : 'Board View', style: const TextStyle(fontSize: 14)),
                        ),
                        ElevatedButton(
                          onPressed: () => _openAddDialog(),
                          style: _smallPillStyle(filled: true),
                          child: const Text('+ Add Task', style: TextStyle(fontSize: 14)),
                        ),
                        // Responsive 4-cell stats block
                        LayoutBuilder(builder: (ctx, caps) {
                          final availableWidth = (caps.maxWidth.isFinite && caps.maxWidth > 0)
                              ? caps.maxWidth
                              : MediaQuery.of(context).size.width;

                          const wideThreshold = 600.0;
                          final wide = availableWidth >= wideThreshold;

                          if (wide) {
                            return Row(
                              children: [
                                Expanded(child: _statTile('Pending Tasks', stats['pending'] ?? 0, onTap: () => _openStatsModal('pending', 'Pending Tasks'))),
                                const SizedBox(width: 8),
                                Expanded(child: _statTile('Completed', stats['completed'] ?? 0, onTap: () => _openStatsModal('completed', 'Completed Tasks'))),
                                const SizedBox(width: 8),
                                Expanded(child: _statTile('High Priority', stats['high'] ?? 0, onTap: () => _openStatsModal('high', 'High Priority'))),
                                const SizedBox(width: 8),
                                Expanded(child: _statTile('Due This Week', stats['dueWeek'] ?? 0, onTap: () => _openStatsModal('week', 'Due This Week'))),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _statTile('Pending Tasks', stats['pending'] ?? 0, onTap: () => _openStatsModal('pending', 'Pending Tasks'))),
                                  const SizedBox(width: 8),
                                  Expanded(child: _statTile('Completed', stats['completed'] ?? 0, onTap: () => _openStatsModal('completed', 'Completed Tasks'))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _statTile('High Priority', stats['high'] ?? 0, onTap: () => _openStatsModal('high', 'High Priority'))),
                                  const SizedBox(width: 8),
                                  Expanded(child: _statTile('Due This Week', stats['dueWeek'] ?? 0, onTap: () => _openStatsModal('week', 'Due This Week'))),
                                ],
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // main grid
                    LayoutBuilder(builder: (context, constraints) {
                      final twoCol = constraints.maxWidth >= 1000;
                      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          flex: twoCol ? 3 : 1,
                          child: Column(children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE6EDF3))),
                              child: Column(children: [
                                // responsive header: place title, then centered segmented control full-width, then search & sort
                                LayoutBuilder(builder: (context, hb) {
                                  // We'll always center the segmented control under the "All Tasks" title.
                                  final segMaxWidth = hb.maxWidth >= 520 ? 460.0 : hb.maxWidth * 0.9;
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Title row
                                      Row(children: [
                                        const Expanded(child: Text('All Tasks', style: TextStyle(fontWeight: FontWeight.w800))),
                                        if (hb.maxWidth >= 720)
                                          // on wide screens, keep an optional small spacer to the right (visual balance)
                                          const SizedBox(width: 8),
                                      ]),
                                      const SizedBox(height: 12),

                                      // Centered segmented control (constrained width so it doesn't stretch too wide)
                                      Center(
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(maxWidth: segMaxWidth, minWidth: 200),
                                          child: _segmentedControl(),
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Search + Sort row sits below the segmented control
                                      Row(children: [
                                        Expanded(child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search tasks...', isDense: true), onChanged: (v) { setState(() => search = v); })),
                                        const SizedBox(width: 12),
                                        const Text('Sort', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey)),
                                        const SizedBox(width: 8),
                                        DropdownButton<SortBy>(value: sortBy, items: const [
                                          DropdownMenuItem(value: SortBy.due, child: Text('Due date')),
                                          DropdownMenuItem(value: SortBy.priority, child: Text('Priority')),
                                          DropdownMenuItem(value: SortBy.created, child: Text('Newest')),
                                        ], onChanged: (v) { if (v != null) setState(() => sortBy = v); }),
                                      ]),
                                    ],
                                  );
                                }),
                                const SizedBox(height: 12),
                                // Constrain the list area so nested scrolling won't overflow on small devices.
                                Builder(builder: (ctx) {
                                  final deviceH = MediaQuery.of(ctx).size.height;
                                  var maxListHeight = deviceH * (twoCol ? 0.6 : 0.55);

                                  // subtract a small safety margin to prevent "bottom overflowed by 16px"
                                  maxListHeight = (maxListHeight - 16).clamp(120.0, deviceH);

                                  // compute visible tasks per show-more state
                                  final visibleTasks = _showMoreTasks ? filtered : filtered.take(_maxVisibleTasks).toList();

                                  // We'll animate height changes with AnimatedSize (so toggling show-more smoothly animates)
                                  return AnimatedSize(
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeInOut,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // WHEN COLLAPSED: keep a fixed-height box with scroll inside
                                        if (!_showMoreTasks)
                                          SizedBox(
                                            height: maxListHeight,
                                            child: filtered.isEmpty
                                                ? const Padding(padding: EdgeInsets.all(18), child: Text('No tasks found.'))
                                                : ListView.builder(
                                                    shrinkWrap: true,
                                                    physics: const NeverScrollableScrollPhysics(),
                                                    itemCount: visibleTasks.length,
                                                    itemBuilder: (context, i) {
                                                      final t = visibleTasks[i];
                                                      if (timelineView) {
                                                        return _timelineEntry(t);
                                                      }
                                                      return _taskCard(t);
                                                    },
                                                  ),
                                          )
                                        else
                                          // WHEN EXPANDED: allow the list to size to its content but cap its max height to avoid overflow.
                                          ConstrainedBox(
                                            constraints: BoxConstraints(maxHeight: (deviceH * 0.9).clamp(200.0, deviceH * 0.95)),
                                            child: filtered.isEmpty
                                                ? const Padding(padding: EdgeInsets.all(18), child: Text('No tasks found.'))
                                                : ListView.builder(
                                                    shrinkWrap: true,
                                                    physics: const NeverScrollableScrollPhysics(),
                                                    itemCount: visibleTasks.length,
                                                    itemBuilder: (context, i) {
                                                      final t = visibleTasks[i];
                                                      if (timelineView) {
                                                        return _timelineEntry(t);
                                                      }
                                                      return _taskCard(t);
                                                    },
                                                  ),
                                          ),

                                        // ---- show more pill placed BETWEEN tasks and Upcoming Deadlines ----
                                        if (filtered.length > _maxVisibleTasks) _showMoreTasksPill(),
                                      ],
                                    ),
                                  );
                                }),
                              ]),
                            ),
                          ]),
                        ),
                        if (twoCol) const SizedBox(width: 18),
                        if (twoCol)
                          SizedBox(
                            width: 340,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE6EDF3))),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Upcoming Deadlines', style: TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                _upcomingDeadlines(),
                                const SizedBox(height: 18),
                                const Text('Quick Stats', style: TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                // Avg Completion removed as requested
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Overdue'), Text('${stats['overdue']}')]),
                                const SizedBox(height: 18),
                                ElevatedButton(onPressed: () => _openRecoverModal(), style: _smallPillStyle(filled: true), child: const Text('View Recoverable'))
                              ]),
                            ),
                          ),
                      ]);
                    }),
                    const SizedBox(height: 24),

                    // Narrow layout: Upcoming Deadlines & Quick Stats card (below tasks). For wide (twoCol) layout the right-side box already shows it.
                    if (!isWide)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE6EDF3))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Upcoming Deadlines', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          _upcomingDeadlines(),
                          const SizedBox(height: 18),
                          const Text('Quick Stats', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          // Avg Completion removed as requested
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Overdue'), Text('${stats['overdue']}')]),
                          const SizedBox(height: 18),
                          ElevatedButton(onPressed: () => _openRecoverModal(), style: _smallPillStyle(filled: true), child: const Text('View Recoverable'))
                        ]),
                      )

                  ]),
                ),

              ]),
            ),

            // Bottom-right pill group (horizontal next to each other)
            Positioned(
              right: 18,
              bottom: 18,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Toggle Timeline/Board
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        timelineView = !timelineView;
                      });
                    },
                    icon: Icon(timelineView ? Icons.timeline : Icons.grid_view, size: 16),
                    label: Text(timelineView ? 'Timeline' : 'Board', style: const TextStyle(fontSize: 13)),
                    style: _smallPillStyle(filled: true),
                  ),
                  const SizedBox(width: 8),
                  // Reset (outlined)
                  OutlinedButton.icon(
                    onPressed: () {
                      _resetSample();
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset', style: TextStyle(fontSize: 13)),
                    style: _smallPillStyle(filled: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timelineEntry(Task t) {
    final diff = daysDiff(t.dueDateIso);
    final overdue = diff < 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 44, height: 44, child: CircleAvatar(backgroundColor: Color(0xFF0EA5E9))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          t.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(fmtDate(t.dueDateIso), style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (t.course.isNotEmpty)
                    Text('Course: ${t.course}', style: TextStyle(color: Colors.grey[700], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (t.course.isNotEmpty) const SizedBox(height: 6),
                  Text(
                    t.desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _typeChip(t.type),
                      _priorityChip(t.priority),
                      if (overdue)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFFFF7F7), borderRadius: BorderRadius.circular(8)),
                          child: Text('${diff.abs()}d overdue', style: const TextStyle(color: Colors.red, fontSize: 12)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8)),
                          child: Text('$diff d', style: const TextStyle(color: Color(0xFFC2410C), fontSize: 12)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 56,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Meetings-style edit circle
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _openAddDialog(edit: t),
                      child: const Icon(Icons.edit, color: Colors.white, size: 18),
                    ),
                  ),

                  // lower the trash further (matches meetings screenshot)
                  const SizedBox(height: 18),

                  IconButton(
                    onPressed: () => _confirmDelete(t),
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, int value, {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE6EDF3))),
          child: Column(children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Text(
              '$value',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _upcomingDeadlines() {
    final today = DateTime.now();
    final in7 = today.add(const Duration(days: 7));
    final upcoming = tasks.where((t) {
      final d = DateTime.tryParse(t.dueDateIso);
      if (d == null) return false;
      final dt = DateTime(d.year, d.month, d.day);
      return dt.isAfter(DateTime(today.year, today.month, today.day - 1)) && dt.isBefore(in7.add(const Duration(days: 1)));
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a.dueDateIso);
        final db = DateTime.tryParse(b.dueDateIso);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

    if (upcoming.isEmpty) return const Text('No upcoming deadlines.', style: TextStyle(color: Colors.grey));

    return Column(children: upcoming.take(5).map((t) {
      final diff = daysDiff(t.dueDateIso);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text(t.desc, maxLines: 2, overflow: TextOverflow.ellipsis),
          ])),
          Column(children: [
            if (diff < 0)
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFFFF7F7), borderRadius: BorderRadius.circular(8)), child: Text('${diff.abs()}d overdue', style: const TextStyle(color: Colors.red))),
            if (diff >= 0)
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8)), child: Text('$diff d', style: const TextStyle(color: Color(0xFFC2410C)))),
            const SizedBox(height: 8),
            // progress bar removed per request
          ])
        ]),
      );
    }).toList());
  }

  Future<void> _resetSample() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(storageKey);
    tasks.clear();
    await _loadFromStorage();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reset sample tasks')));
  }
}

// Animated thumb widget that positions itself behind active button using GlobalKeys
class _AnimatedSegThumb extends StatefulWidget {
  final Map<String, GlobalKey> keys;
  final GlobalKey activeKey;
  final Color colorA;
  final Color colorB;
  /// amount to inflate the active rect (breathing room). made configurable to support compact mode.
  final double inflate;
  const _AnimatedSegThumb({required this.keys, required this.activeKey, required this.colorA, required this.colorB, this.inflate = 6.0});

  @override
  State<_AnimatedSegThumb> createState() => _AnimatedSegThumbState();
}

class _AnimatedSegThumbState extends State<_AnimatedSegThumb> {
  Rect? _curRect;

  static const Duration _animDuration = Duration(milliseconds: 300);
  static const Curve _animCurve = Curves.easeInOut;

  void _update() {
    final activeBox = widget.activeKey.currentContext?.findRenderObject() as RenderBox?;
    final parentBox = context.findRenderObject() as RenderBox?;
    if (activeBox == null || parentBox == null) return;

    final parentSize = parentBox.size;
    if (parentSize.width <= 0 || parentSize.height <= 0) return;

    final activeRect = activeBox.localToGlobal(Offset.zero, ancestor: parentBox) & activeBox.size;
    var newRect = activeRect.inflate(widget.inflate);

    // clamp width/height so it never exceeds parent
    final w = newRect.width.clamp(0.0, parentSize.width);
    final h = newRect.height.clamp(0.0, parentSize.height);

    // ensure thumb doesn't grow so wide it covers neighbors entirely on tiny screens:
    final minW = (activeBox.size.width).clamp(24.0, parentSize.width);
    final finalW = w.clamp(minW, parentSize.width);

    final maxLeft = (parentSize.width - finalW).clamp(0.0, double.infinity);
    final clampedLeft = newRect.left.clamp(0.0, maxLeft);
    final maxTop = (parentSize.height - h).clamp(0.0, double.infinity);
    final clampedTop = newRect.top.clamp(0.0, maxTop);

    newRect = Rect.fromLTWH(clampedLeft, clampedTop, finalW, h);

    // Directly set _curRect to newRect. AnimatedPositioned will animate between previous and new values.
    setState(() {
      _curRect = newRect;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void didUpdateWidget(covariant _AnimatedSegThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  Widget build(BuildContext context) {
    if (_curRect == null) {
      // If we don't yet have a rect, return a zero-size placeholder so the Stack layout is stable.
      return const SizedBox();
    }

    // sanitize values
    final left = _curRect!.left.isFinite && _curRect!.left >= 0 ? _curRect!.left : 0.0;
    final top = _curRect!.top.isFinite && _curRect!.top >= 0 ? _curRect!.top : 0.0;
    final width = _curRect!.width.isFinite && _curRect!.width > 0 ? _curRect!.width : 0.0;
    final height = _curRect!.height.isFinite && _curRect!.height > 0 ? _curRect!.height : 0.0;

    if (width <= 0 || height <= 0) return const SizedBox();

    return AnimatedPositioned(
      left: left,
      top: top,
      width: width,
      height: height,
      duration: _animDuration,
      curve: _animCurve,
      child: AnimatedContainer(
        duration: _animDuration,
        curve: _animCurve,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [widget.colorA, widget.colorB]),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: widget.colorB.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 8))],
        ),
      ),
    );
  }
}
