// lib/admin/planner_dashboard.dart
// Enhanced Planner with improved UI/UX: undo delete, drag handle + animations, filters, tag colors, calendar date view

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  });

  String id;
  String title;
  String desc;
  String type;
  String priority;
  String dueDateIso;
  int progress;
  bool completed;
  String createdAtIso;

  factory Task.fromApi(Map<String, dynamic> m) {
    return Task(
      id: m['id'].toString(),
      title: (m['title'] ?? '').toString(),
      desc: (m['notes'] ?? '').toString(),
      type: (m['type'] ?? 'assignment').toString(),
      priority: (m['priority'] ?? 'medium').toString(),
      dueDateIso: (m['due'] ?? '').toString(),
      progress: int.tryParse(m['progress']?.toString() ?? '0') ?? 0,
      completed: m['completed'] == true,
      createdAtIso: (m['created_at'] ?? DateTime.now().toIso8601String()).toString(),
    );
  }

  factory Task.fromJson(Map<String, dynamic> m) {
    return Task(
      id: m['id']?.toString() ?? UniqueKey().toString(),
      title: (m['title'] ?? '').toString(),
      desc: (m['desc'] ?? '').toString(),
      type: (m['type'] ?? 'assignment').toString(),
      priority: (m['priority'] ?? 'medium').toString(),
      dueDateIso: (m['dueDateIso'] ?? '').toString(),
      progress: m['progress'] ?? 0,
      completed: m['completed'] ?? false,
      createdAtIso: (m['createdAtIso'] ?? DateTime.now().toIso8601String()).toString(),
    );
  }

  Map<String, dynamic> toApi() {
    return {
      'title': title,
      'notes': desc,
      'type': type,
      'priority': priority,
      'due': dueDateIso,
      'progress': progress,
      'completed': completed,
    };
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'desc': desc,
        'type': type,
        'priority': priority,
        'dueDateIso': dueDateIso,
        'progress': progress,
        'completed': completed,
        'createdAtIso': createdAtIso,
      };
}

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key});

  @override
  State<PlannerPage> createState() => _PlannerHomePage();
}

enum SortBy { due, priority, created }

class _PlannerHomePage extends State<PlannerPage> with SingleTickerProviderStateMixin {
  final List<Task> tasks = [];
  String currentTab = 'all';
  String search = '';
  SortBy sortBy = SortBy.due;
  late final DateFormat dateFormatter;

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _fabExpanded = false;
  late AnimationController _fabController;
  late Animation<double> _fabScale;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleCtl = TextEditingController();
  final TextEditingController _descCtl = TextEditingController();
  final TextEditingController _dueDateCtl = TextEditingController();
  String _type = 'assignment';
  String _priority = 'medium';
  bool _completed = false;
  String? _editingId;
  DateTime? _pickedDate;

  static const Color segEmerald = Color(0xFF059669);
  final int _maxVisibleTasks = 6;
  bool _showMoreTasks = false;

  // Local cache key
  static const String _cacheKey = 'planner_tasks_cache_v1';

  // Undo delete state
  Task? _lastRemovedTask;
  int? _lastRemovedIndex;

  // Filters
  final Set<String> _typeFilters = {}; // e.g. 'assignment','project'
  final Set<String> _priorityFilters = {}; // 'high','medium','low'

  // Tag colors
  final Map<String, Color> _typeColor = {
    'assignment': Colors.blue.shade100,
    'study': Colors.purple.shade100,
    'project': Colors.teal.shade100,
    'exam': Colors.amber.shade100,
  };

  final Map<String, Color> _priorityColorBg = {
    'high': Colors.red.shade100,
    'medium': Colors.orange.shade100,
    'low': Colors.green.shade100,
  };

  final Map<String, Color> _priorityColorText = {
    'high': Colors.red.shade700,
    'medium': Colors.orange.shade800,
    'low': Colors.green.shade800,
  };

  @override
  void initState() {
    super.initState();
    dateFormatter = DateFormat.yMMMEd();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fabController, curve: Curves.easeOut));

    // Load cached tasks immediately for snappy UI, then refresh from API
    _loadCachedTasks().then((_) => _loadTasksFromApi());
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    _dueDateCtl.dispose();
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = tasks.map((t) => t.toJson()).toList();
      await prefs.setString(_cacheKey, jsonEncode(list));
    } catch (e) {
      // ignore cache errors
    }
  }

  Future<void> _loadCachedTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List<dynamic>;
      setState(() {
        tasks.clear();
        tasks.addAll(list.map((m) => Task.fromJson(Map<String, dynamic>.from(m))));
      });
    } catch (e) {
      // ignore
    }
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

      await _saveCache();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Failed to load tasks: $e — showing cached data');
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
      await _saveCache();
      _showSnack('Data refreshed');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRefreshing = false);
      _showSnack('Refresh failed — showing cached data');
    }
  }

  Future<void> _createTaskApi(Task task) async {
    try {
      final result = await ApiService.createTask(task.toApi());

      if (result['success'] == true) {
        await _loadTasksFromApi();
        _showSnack('Task created successfully');
      } else {
        _showSnack('Failed: ${result['message']}');
      }
    } catch (e) {
      _showSnack('Error: $e');
      // add locally to keep the user flow smooth
      setState(() => tasks.insert(0, task));
      await _saveCache();
    }
  }

  Future<void> _updateTaskApi(String taskId, Map<String, dynamic> updates) async {
    try {
      final result = await ApiService.updateTask(taskId, updates);

      if (result['success'] == true) {
        await _loadTasksFromApi();
      } else {
        _showSnack('Failed: ${result['message']}');
      }
    } catch (e) {
      _showSnack('Error: $e');
      // optimistic update for local cache
      final idx = tasks.indexWhere((t) => t.id == taskId);
      if (idx != -1) {
        final t = tasks[idx];
        if (updates.containsKey('completed')) t.completed = updates['completed'];
        await _saveCache();
      }
    }
  }

  Future<void> _deleteTaskApi(String taskId) async {
    try {
      final result = await ApiService.deleteTask(taskId);

      if (result['success'] == true) {
        await _loadTasksFromApi();
        _showSnack('Task deleted');
      } else {
        _showSnack('Failed: ${result['message']}');
      }
    } catch (e) {
      _showSnack('Error: $e — removed locally');
      setState(() => tasks.removeWhere((t) => t.id == taskId));
      await _saveCache();
    }
  }

  Future<void> _bulkComplete() async {
    final pending = tasks.where((t) => !t.completed).toList();

    if (pending.isEmpty) {
      _showSnack('No pending tasks');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Complete All'),
        content: Text('Mark ${pending.length} pending task(s) as complete?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: segEmerald),
            child: const Text('Complete All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    int completed = 0;
    for (var task in pending) {
      try {
        await ApiService.updateTask(task.id, {'completed': true});
        completed++;
      } catch (e) {
        // Continue with others but also update locally
        task.completed = true;
      }
    }

    await _saveCache();
    await _loadTasksFromApi();
    _showSnack('Completed $completed task(s)');
  }

  Future<void> _exportTasks() async {
    if (tasks.isEmpty) {
      _showSnack('No tasks to export');
      return;
    }

    final csv = StringBuffer();
    csv.writeln('id,title,notes,type,priority,due,completed,created_at');
    for (var t in tasks) {
      csv.writeln('"${t.id}","${t.title.replaceAll('"', '""')}","${t.desc.replaceAll('"', '""')}","${t.type}","${t.priority}","${t.dueDateIso}","${t.completed}","${t.createdAtIso}"');
    }

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('CSV Preview'),
        content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Text(csv.toString()))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _archiveCompleted() async {
    final completed = tasks.where((t) => t.completed).toList();

    if (completed.isEmpty) {
      _showSnack('No completed tasks to archive');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Archive Completed'),
        content: Text('Archive ${completed.length} completed task(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    int archived = 0;
    for (var task in completed) {
      try {
        await ApiService.deleteTask(task.id);
        archived++;
      } catch (e) {
        // remove locally
        tasks.remove(task);
        archived++;
      }
    }

    await _saveCache();
    await _loadTasksFromApi();
    _showSnack('Archived $archived task(s)');
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
      final matchesSearch = q.isEmpty || t.title.toLowerCase().contains(q) || t.desc.toLowerCase().contains(q);
      if (!matchesSearch) return false;
      if (_typeFilters.isNotEmpty && !_typeFilters.contains(t.type)) return false;
      if (_priorityFilters.isNotEmpty && !_priorityFilters.contains(t.priority)) return false;
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
    } else {
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
    final overdue = tasks.where((t) => daysDiff(t.dueDateIso) < 0 && !t.completed).length;
    return {'pending': pending, 'completed': completed, 'high': high, 'overdue': overdue};
  }

  Future<void> _openAddDialog({Task? edit}) async {
    _editingId = edit?.id;
    if (edit != null) {
      _titleCtl.text = edit.title;
      _descCtl.text = edit.desc;
      _type = edit.type;
      _priority = edit.priority;
      _completed = edit.completed;
      _pickedDate = DateTime.tryParse(edit.dueDateIso);
      _dueDateCtl.text = _pickedDate == null ? '' : DateFormat('yyyy-MM-dd').format(_pickedDate!);
    } else {
      _editingId = null;
      _titleCtl.clear();
      _descCtl.clear();
      _type = 'assignment';
      _priority = 'medium';
      _completed = false;
      _pickedDate = null;
      _dueDateCtl.clear();
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(_editingId == null ? 'Add Task' : 'Edit Task',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(ctx),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(color: segEmerald, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _titleCtl,
                          decoration: InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _type,
                                decoration: InputDecoration(
                                  labelText: 'Type',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
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
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _pickedDate ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    _pickedDate = picked;
                                    _dueDateCtl.text = DateFormat('yyyy-MM-dd').format(picked);
                                    setState(() {});
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: segEmerald,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                icon: const Icon(Icons.calendar_today, size: 16),
                                label: Text(_dueDateCtl.text.isEmpty ? 'Due Date' : _dueDateCtl.text,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _priority,
                          decoration: InputDecoration(
                            labelText: 'Priority',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'low', child: Text('Low')),
                            DropdownMenuItem(value: 'medium', child: Text('Medium')),
                            DropdownMenuItem(value: 'high', child: Text('High')),
                          ],
                          onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descCtl,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Checkbox(value: _completed, onChanged: (v) => setState(() => _completed = v ?? false)),
                            const Text('Mark completed'),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (!_formKey.currentState!.validate()) return;
                                  if (_pickedDate == null) {
                                    _showSnack('Select a due date');
                                    return;
                                  }

                                  final task = Task(
                                    id: _editingId ?? UniqueKey().toString(),
                                    title: _titleCtl.text.trim(),
                                    desc: _descCtl.text.trim(),
                                    type: _type,
                                    priority: _priority,
                                    dueDateIso: _pickedDate!.toIso8601String(),
                                    progress: 0,
                                    completed: _completed,
                                    createdAtIso: DateTime.now().toIso8601String(),
                                  );

                                  Navigator.pop(ctx);

                                  if (_editingId != null && _editingId!.isNotEmpty) {
                                    await _updateTaskApi(_editingId!, task.toApi());
                                  } else {
                                    await _createTaskApi(task);
                                  }

                                  // reset quick fields
                                  setState(() {
                                    _pickedDate = null;
                                    _dueDateCtl.clear();
                                  });
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: segEmerald, foregroundColor: Colors.white),
                                child: Text(_editingId == null ? 'Add' : 'Save'),
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
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(Task t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete task?'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final idx = tasks.indexWhere((x) => x.id == t.id);
      if (idx != -1) {
        _performLocalRemoveWithUndo(idx);
      }
    }
  }

  // Remove locally and show undo SnackBar. If not undone, perform remote delete.
  void _performLocalRemoveWithUndo(int index) {
    _lastRemovedTask = tasks[index];
    _lastRemovedIndex = index;
    setState(() => tasks.removeAt(index));
    _saveCache();

    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task removed'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Undo', onPressed: () {
          // undo
          if (_lastRemovedTask != null && _lastRemovedIndex != null) {
            setState(() {
              tasks.insert(_lastRemovedIndex!, _lastRemovedTask!);
              _lastRemovedTask = null;
              _lastRemovedIndex = null;
            });
            _saveCache();
          }
        }),
      ),
    );

    controller.closed.then((reason) async {
      // if user pressed undo, _lastRemovedTask will be null
      if (_lastRemovedTask != null) {
        final id = _lastRemovedTask!.id;
        try {
          await ApiService.deleteTask(id);
        } catch (_) {
          // ignore network error; cache already updated
        }
        _lastRemovedTask = null;
        _lastRemovedIndex = null;
      }
    });
  }

  Widget _taskSegmentedControl(List<String> tabs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: tabs.map((tab) {
          final bool active = currentTab == tab;
          final String label = tab[0].toUpperCase() + tab.substring(1);

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => currentTab = tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: active
                    ? BoxDecoration(
                        color: segEmerald,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      )
                    : const BoxDecoration(color: Colors.transparent),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
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
  }

  Widget _chipSelectable(String text, Color bg, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? bg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? Colors.transparent : Colors.grey.shade200),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Widget _taskCard(Task t, int index) {
    final diff = daysDiff(t.dueDateIso);
    final overdue = diff < 0;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      child: Dismissible(
        key: ValueKey(t.id),
        background: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerLeft,
          color: Colors.red.shade400,
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        secondaryBackground: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerRight,
          color: Colors.red.shade400,
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (dir) async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Delete'),
              content: const Text('Delete this task?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
              ],
            ),
          );
          return ok == true;
        },
        onDismissed: (_) async {
          // use undo flow
          final realIndex = index;
          _performLocalRemoveWithUndo(realIndex);
        },
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF6EEF8),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                ReorderableDragStartListener(
                  index: index,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8, top: 6),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.drag_handle, size: 18, color: Colors.black54),
                  ),
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                          const SizedBox(width: 8),
                          Text(fmtDate(t.dueDateIso), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (t.desc.isNotEmpty)
                        Text(t.desc, style: TextStyle(fontSize: 13, color: Colors.grey.shade700), maxLines: 2),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Type chip with color
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _typeColor[t.type] ?? Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(t.type, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),

                          // Priority chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _priorityColorBg[t.priority] ?? Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              t.priority,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _priorityColorText[t.priority]),
                            ),
                          ),

                          // Due chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: overdue ? Colors.red.shade50 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              overdue ? '${diff.abs()}d overdue' : '$diff d left',
                              style: TextStyle(
                                color: overdue ? Colors.red.shade700 : Colors.grey.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _openAddDialog(edit: t),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Icon(Icons.edit, color: segEmerald, size: 20),
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => _confirmDelete(t),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Icon(Icons.delete, color: Colors.red, size: 20),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Transform.scale(
                      scale: 1.1,
                      child: Checkbox(
                        value: t.completed,
                        onChanged: (v) async {
                          setState(() => t.completed = v ?? false);
                          await _saveCache();
                          await _updateTaskApi(t.id, {'completed': v ?? false});
                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        activeColor: segEmerald,
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

  // Calendar: pick a date and show tasks for that day
  Future<void> _openCalendarView() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) return;

    final list = tasks.where((t) {
      final d = DateTime.tryParse(t.dueDateIso);
      if (d == null) return false;
      return d.year == picked.year && d.month == picked.month && d.day == picked.day;
    }).toList();

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Tasks on ${DateFormat.yMMMd().format(picked)}'),
        content: SizedBox(
          width: double.maxFinite,
          child: list.isEmpty
              ? const Text('No tasks on this date')
              : SingleChildScrollView(child: Column(children: list.map((t) => ListTile(title: Text(t.title), subtitle: Text(t.desc))).toList())),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Widget _statTileColored(String label, int value, Color bg) {
    return Container(
      height: 86,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 6),
          Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = getFilteredSorted();
    final stats = computeStats();
    final visible = _showMoreTasks ? filtered : filtered.take(_maxVisibleTasks).toList();

    final tabs = ['all', 'pending', 'completed', 'high'];

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF7),
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _refreshTasks,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Stats at top
                    Row(
                      children: [
                        Expanded(child: _statTileColored('Pending', stats['pending']!, Colors.blue.shade400)),
                        const SizedBox(width: 10),
                        Expanded(child: _statTileColored('Done', stats['completed']!, Colors.green.shade400)),
                        const SizedBox(width: 10),
                        Expanded(child: _statTileColored('High', stats['high']!, Colors.red.shade400)),
                        const SizedBox(width: 10),
                        Expanded(child: _statTileColored('Overdue', stats['overdue']!, Colors.orange.shade400)),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        const Text('Planner', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                        const Spacer(),
                        IconButton(
                          icon: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.refresh),
                          onPressed: _isLoading ? null : _refreshTasks,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Search + Sort + Calendar row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.search, size: 20, color: Colors.black54),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    onChanged: (v) => setState(() => search = v),
                                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'Search tasks...'),
                                  ),
                                ),
                                if (search.isNotEmpty)
                                  InkWell(
                                    onTap: () => setState(() => search = ''),
                                    child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.close, size: 18)),
                                  )
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: PopupMenuButton<SortBy>(
                            onSelected: (s) => setState(() => sortBy = s),
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: SortBy.due, child: Text('Sort by Due')),
                              const PopupMenuItem(value: SortBy.priority, child: Text('Sort by Priority')),
                              const PopupMenuItem(value: SortBy.created, child: Text('Sort by Created')),
                            ],
                            icon: const Icon(Icons.sort),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: IconButton(onPressed: _openCalendarView, icon: const Icon(Icons.calendar_today)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Filters row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const SizedBox(width: 4),
                          _chipSelectable('All types', Colors.blue, _typeFilters.isEmpty, () => setState(() => _typeFilters.clear())),
                          const SizedBox(width: 8),
                          ..._typeColor.keys.map((k) => Padding(padding: const EdgeInsets.only(right: 8), child: _chipSelectable(k, _typeColor[k]!, _typeFilters.contains(k), () => setState(() => _typeFilters.contains(k) ? _typeFilters.remove(k) : _typeFilters.add(k))))).toList(),
                          const SizedBox(width: 12),
                          _chipSelectable('All priorities', Colors.orange, _priorityFilters.isEmpty, () => setState(() => _priorityFilters.clear())),
                          const SizedBox(width: 8),
                          ..._priorityColorBg.keys.map((k) => Padding(padding: const EdgeInsets.only(right: 8), child: _chipSelectable(k, _priorityColorBg[k]!, _priorityFilters.contains(k), () => setState(() => _priorityFilters.contains(k) ? _priorityFilters.remove(k) : _priorityFilters.add(k))))).toList(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    _taskSegmentedControl(tabs),

                    const SizedBox(height: 12),

                    // Task list
                    if (filtered.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text('No tasks yet', style: TextStyle(color: Colors.grey.shade600)),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => _openAddDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Add your first task'),
                                style: ElevatedButton.styleFrom(backgroundColor: segEmerald),
                              )
                            ],
                          ),
                        ),
                      )
                    else
                      // Reorderable list for drag-and-drop with handles and animated size
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        onReorder: (oldIndex, newIndex) async {
                          if (oldIndex < newIndex) newIndex -= 1;
                          final moving = filtered[oldIndex];
                          final oldReal = tasks.indexWhere((t) => t.id == moving.id);

                          // compute newReal as the position of the item at newIndex in filtered list mapped to tasks
                          int newReal;
                          if (newIndex >= filtered.length) {
                            newReal = tasks.length - 1;
                          } else {
                            final nextItem = filtered[newIndex];
                            newReal = tasks.indexWhere((t) => t.id == nextItem.id);
                          }

                          setState(() {
                            final t = tasks.removeAt(oldReal);
                            final insertAt = newReal > oldReal ? newReal : newReal;
                            tasks.insert(insertAt, t);
                          });

                          await _saveCache();
                        },
                        buildDefaultDragHandles: false, // we use our own handles
                        itemBuilder: (ctx, idx) {
                          final t = filtered[idx];
                          final realIndex = tasks.indexWhere((x) => x.id == t.id);
                          return Padding(
                            key: ValueKey(t.id),
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            child: _taskCard(t, realIndex),
                          );
                        },
                      ),

                    const SizedBox(height: 12),
                    if (filtered.length > _maxVisibleTasks)
                      TextButton(
                        onPressed: () => setState(() => _showMoreTasks = !_showMoreTasks),
                        child: Text(_showMoreTasks ? 'Show less' : 'Show more'),
                      ),

                    const SizedBox(height: 100), // space for FAB
                  ],
                ),
              ),
            ),
          ),

          // FAB overlay when expanded
          if (_fabExpanded)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleFAB,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _fabExpanded ? 0.6 : 0.0,
                  child: Container(color: Colors.black54),
                ),
              ),
            ),
        ],
      ),

      floatingActionButton: SizedBox(
        width: 240,
        height: 56,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            // Expanded actions
            Positioned(
              right: 0,
              bottom: 64,
              child: ScaleTransition(
                scale: _fabScale,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: 'bulk',
                      onPressed: () {
                        _toggleFAB();
                        _bulkComplete();
                      },
                      label: const Text('Complete all'),
                      icon: const Icon(Icons.done_all),
                      backgroundColor: Colors.blue,
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.extended(
                      heroTag: 'export',
                      onPressed: () {
                        _toggleFAB();
                        _exportTasks();
                      },
                      label: const Text('Export'),
                      icon: const Icon(Icons.file_download),
                      backgroundColor: Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.extended(
                      heroTag: 'archive',
                      onPressed: () {
                        _toggleFAB();
                        _archiveCompleted();
                      },
                      label: const Text('Archive done'),
                      icon: const Icon(Icons.archive),
                      backgroundColor: Colors.green,
                    ),
                  ],
                ),
              ),
            ),

            // Primary FAB
            Positioned(
              right: 0,
              bottom: 0,
              child: FloatingActionButton(
                onPressed: _toggleFAB,
                backgroundColor: segEmerald,
                child: AnimatedBuilder(
                  animation: _fabController,
                  builder: (_, __) {
                    return Transform.rotate(
                      angle: _fabController.value * 0.5,
                      child: Icon(_fabExpanded ? Icons.close : Icons.menu),
                    );
                  },
                ),
              ),
            ),

            // Quick-add pill fixed and improved
            Positioned(
              right: 100,
              bottom: 6,
              child: GestureDetector(
                onTap: () => _openAddDialog(),
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, size: 18, color: segEmerald),
                        const SizedBox(width: 8),
                        const Text('Quick add', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
