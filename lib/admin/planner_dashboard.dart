// lib/admin/planner_dashboard.dart
// Enhanced Planner with unified emerald gradient action buttons and updated Add Task sheet UI.
// Bottom sheet UI matches the Meetings page (rounded sheet, emerald gradient buttons, pill-style actions).

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
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
      createdAtIso:
          (m['created_at'] ?? DateTime.now().toIso8601String()).toString(),
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
}

// Shared gradient colors used across app pages
const Color themeStart = Color(0xFF10B981); // emerald-500
const Color themeEnd = Color(0xFF059669); // emerald-600

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key});

  @override
  State<PlannerPage> createState() => _PlannerHomePage();
}

enum SortBy { due, priority, created }

class _PlannerHomePage extends State<PlannerPage>
    with SingleTickerProviderStateMixin {
  final List<Task> tasks = [];
  String currentTab = 'all';
  String search = '';
  SortBy sortBy = SortBy.due;
  late final DateFormat dateFormatter;

  bool _isLoading = false;
  bool _isRefreshing = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleCtl = TextEditingController();
  final TextEditingController _descCtl = TextEditingController();
  final TextEditingController _dueDateCtl = TextEditingController();
  String _type = 'assignment';
  String _priority = 'medium';
  bool _completed = false;
  String? _editingId;
  DateTime? _pickedDate;

  // keep older segEmerald constant for places that used it
  static const Color segEmerald = themeEnd;
  final int _maxVisibleTasks = 6;
  bool _showMoreTasks = false;

  @override
  void initState() {
    super.initState();
    dateFormatter = DateFormat.yMMMEd();
    _loadTasksFromApi();
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    _dueDateCtl.dispose();
    super.dispose();
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Failed to load tasks: $e');
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
      _showSnack('Data refreshed');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRefreshing = false);
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
    }
  }

  Future<void> _updateTaskApi(
      String taskId, Map<String, dynamic> updates) async {
    try {
      final result = await ApiService.updateTask(taskId, updates);

      if (result['success'] == true) {
        await _loadTasksFromApi();
      } else {
        _showSnack('Failed: ${result['message']}');
      }
    } catch (e) {
      _showSnack('Error: $e');
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
      _showSnack('Error: $e');
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
        // Continue with others
      }
    }

    await _loadTasksFromApi();
    _showSnack('Completed $completed task(s)');
  }

  Future<void> _exportTasks() async {
    _showSnack('Exporting tasks... (Feature coming soon)');
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
        // Continue
      }
    }

    await _loadTasksFromApi();
    _showSnack('Archived $archived task(s)');
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
      final matchesSearch =
          q.isEmpty || t.title.toLowerCase().contains(q) || t.desc.toLowerCase().contains(q);
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
        // New bottom sheet design — rounded, shadowed, with gradient close and gradient controls
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -6))],
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // grabber
                        Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _editingId == null ? 'Add Task' : 'Edit Task',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [themeStart, themeEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: themeEnd.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 3))],
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 18),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Title
                        TextFormField(
                          controller: _titleCtl,
                          decoration: InputDecoration(
                            hintText: 'Title',
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),

                        // Type dropdown + Due Date pill
                        Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: DropdownButtonFormField<String>(
                                value: _type,
                                decoration: InputDecoration(
                                  labelText: 'Type',
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: Colors.white,
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
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 5,
                              child: _GradientPill(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: _pickedDate ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _pickedDate = picked;
                                      _dueDateCtl.text = DateFormat('yyyy-MM-dd').format(picked);
                                    });
                                  }
                                },
                                icon: Icons.calendar_today,
                                label: _dueDateCtl.text.isEmpty ? 'Due Date' : _dueDateCtl.text,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Priority
                        DropdownButtonFormField<String>(
                          value: _priority,
                          decoration: InputDecoration(
                            labelText: 'Priority',
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'low', child: Text('Low')),
                            DropdownMenuItem(value: 'medium', child: Text('Medium')),
                            DropdownMenuItem(value: 'high', child: Text('High')),
                          ],
                          onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                        ),
                        const SizedBox(height: 12),

                        // Description
                        TextFormField(
                          controller: _descCtl,
                          decoration: InputDecoration(
                            hintText: 'Description',
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
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
                        const SizedBox(height: 16),

                        // Actions: Cancel (outlined) + Add (gradient pill)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('Cancel', style: TextStyle(color: Colors.black87)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  if (!_formKey.currentState!.validate()) return;
                                  if (_pickedDate == null) {
                                    _showSnack('Select a due date');
                                    return;
                                  }

                                  final task = Task(
                                    id: _editingId ?? '',
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
                                  if (_editingId != null) {
                                    await _updateTaskApi(_editingId!, task.toApi());
                                  } else {
                                    await _createTaskApi(task);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [themeStart, themeEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [BoxShadow(color: themeEnd.withOpacity(0.24), blurRadius: 10, offset: const Offset(0, 6))],
                                  ),
                                  child: const Center(child: Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
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
    if (ok == true) await _deleteTaskApi(t.id);
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

  Widget _chip(String text, Color bg, {Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor ?? Colors.black87),
      ),
    );
  }

  Color _priorityColor(String p) {
    if (p == 'high') return Colors.red.shade100;
    if (p == 'low') return Colors.green.shade100;
    return Colors.orange.shade100;
  }

  Widget _taskCard(Task t) {
    final diff = daysDiff(t.dueDateIso);
    final overdue = diff < 0;
    return Container(
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (t.desc.isNotEmpty)
                    Text(t.desc, style: TextStyle(fontSize: 13, color: Colors.grey.shade700), maxLines: 2),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(t.type, Colors.white, textColor: Colors.black87),
                      _chip(t.priority, _priorityColor(t.priority)),
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
                    child: Icon(Icons.edit, color: Colors.green, size: 20),
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
                    onChanged: (v) => _updateTaskApi(t.id, {'completed': v ?? false}),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    activeColor: segEmerald,
                  ),
                ),
              ],
            ),
          ],
        ),
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

  Future<void> _confirmShowMore(int remaining) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Show more tasks?'),
        content: Text('There are $remaining more task(s). Show them?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: segEmerald),
            child: const Text('Show'),
          ),
        ],
      ),
    );

    if (ok == true) {
      setState(() => _showMoreTasks = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = getFilteredSorted();
    final stats = computeStats();
    final visible = _showMoreTasks ? filtered : filtered.take(_maxVisibleTasks).toList();

    final tabs = ['all', 'pending', 'completed', 'high'];
    final remaining = filtered.length > _maxVisibleTasks ? filtered.length - _maxVisibleTasks : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF7),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshTasks,
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
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
                          onPressed: _isLoading ? null : _loadTasksFromApi,
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            setState(() {
                              if (v == 'export') {
                                _exportTasks();
                              } else if (v == 'archive') {
                                _archiveCompleted();
                              } else if (v == 'sort_due') {
                                sortBy = SortBy.due;
                              } else if (v == 'sort_priority') {
                                sortBy = SortBy.priority;
                              } else if (v == 'sort_created') {
                                sortBy = SortBy.created;
                              }
                            });
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'export', child: Text('Export')),
                            const PopupMenuItem(value: 'archive', child: Text('Archive completed')),
                            const PopupMenuDivider(),
                            const PopupMenuItem(value: 'sort_due', child: Text('Sort: Due date')),
                            const PopupMenuItem(value: 'sort_priority', child: Text('Sort: Priority')),
                            const PopupMenuItem(value: 'sort_created', child: Text('Sort: Created')),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search tasks...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (v) => setState(() => search = v),
                    ),
                    const SizedBox(height: 12),
                    _taskSegmentedControl(tabs),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty && !_isLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.inbox, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text('No tasks found', style: TextStyle(color: Colors.grey.shade700)),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      ListView.builder(
                        itemCount: visible.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final t = visible[index];
                          return _taskCard(t);
                        },
                      ),
                      if (filtered.length > _maxVisibleTasks)
                        TextButton(
                          onPressed: () {
                            if (!_showMoreTasks) {
                              _confirmShowMore(remaining);
                            } else {
                              setState(() => _showMoreTasks = false);
                            }
                          },
                          child: Text(_showMoreTasks ? 'Show less' : 'Show more (${filtered.length - _maxVisibleTasks})'),
                        ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),

              // Bottom-right unified gradient action buttons (Archive circular + Add Task pill)
              Positioned(
                right: 18,
                bottom: 18,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [

                    // ARCHIVE — circular gradient button
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [themeStart, themeEnd],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: themeEnd.withOpacity(0.28),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: FloatingActionButton(
                          heroTag: 'archiveFab',
                          onPressed: _archiveCompleted,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          child: const Icon(Icons.archive, color: Colors.white),
                        ),
                      ),
                    ),

                    // ADD TASK — emerald gradient pill (same style)
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [themeStart, themeEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: themeEnd.withOpacity(0.26),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: FloatingActionButton.extended(
                        heroTag: 'addTaskFab',
                        onPressed: () => _openAddDialog(),
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Add Task',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable gradient pill used for Due Date / Join / small gradient buttons
class _GradientPill extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData? icon;
  final String label;
  final EdgeInsetsGeometry? padding;

  const _GradientPill({
    required this.onPressed,
    this.icon,
    required this.label,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [themeStart, themeEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: themeEnd.withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
