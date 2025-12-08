// lib/admin/planner_dashboard.dart
// Enhanced Planner with improved UI/UX and smart FABs (updated: separate FAB toggle, add FAB, animations, confirmations)

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
      createdAtIso: (m['created_at'] ?? DateTime.now().toIso8601String()).toString(),
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

  @override
  void initState() {
    super.initState();
    dateFormatter = DateFormat.yMMMEd();
    _loadTasksFromApi();

    _fabController = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    _dueDateCtl.dispose();
    _fabController.dispose();
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
    // TODO: Implement export to CSV/PDF
  }

  Future<void> _archiveCompleted() async {
    final completed = tasks.where((t) => t.completed).toList();

    if (completed.isEmpty) {
      _showSnack('No completed tasks to archive');
      return;
    }

    // _archiveCompleted already asks confirmation inside
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
        // Call archive API if available, or delete
        await ApiService.deleteTask(task.id);
        archived++;
      } catch (e) {
        // Continue with others
      }
    }

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

    // close FAB menu if open
    if (_fabExpanded) _toggleFAB();

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

    // helpers for staggered slide animations
    final addAnim = CurvedAnimation(parent: _fabController, curve: const Interval(0.0, 0.9, curve: Curves.easeOut));
    final completeAnim = CurvedAnimation(parent: _fabController, curve: const Interval(0.05, 1.0, curve: Curves.easeOut));
    final archiveAnim = CurvedAnimation(parent: _fabController, curve: const Interval(0.1, 1.0, curve: Curves.easeOut));
    final exportAnim = CurvedAnimation(parent: _fabController, curve: const Interval(0.15, 1.0, curve: Curves.easeOut));

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
                            // ask for confirmation before expanding list
                            if (!_showMoreTasks) {
                              _confirmShowMore(remaining);
                            } else {
                              setState(() => _showMoreTasks = false);
                            }
                          },
                          child: Text(_showMoreTasks ? 'Show less' : 'Show more (${filtered.length - _maxVisibleTasks})'),
                        ),
                      const SizedBox(height: 90), // extra space for FAB
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Floating action buttons (expandable) with staggered slide + scale animations
          Positioned(
            bottom: 18,
            right: 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Export FAB
                SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.9), end: Offset.zero).animate(exportAnim),
                  child: FadeTransition(
                    opacity: exportAnim,
                    child: ScaleTransition(
                      scale: exportAnim,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: FloatingActionButton.extended(
                          heroTag: 'exportFab',
                          onPressed: () {
                            _toggleFAB();
                            _exportTasks();
                          },
                          label: const Text('Export'),
                          icon: const Icon(Icons.file_upload),
                          backgroundColor: Colors.purple,
                        ),
                      ),
                    ),
                  ),
                ),

                // Archive FAB
                SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.9), end: Offset.zero).animate(archiveAnim),
                  child: FadeTransition(
                    opacity: archiveAnim,
                    child: ScaleTransition(
                      scale: archiveAnim,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: FloatingActionButton.extended(
                          heroTag: 'archiveFab',
                          onPressed: () {
                            _toggleFAB();
                            _archiveCompleted();
                          },
                          label: const Text('Archive'),
                          icon: const Icon(Icons.archive),
                          backgroundColor: Colors.orange,
                        ),
                      ),
                    ),
                  ),
                ),

                // Complete All FAB
                SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.9), end: Offset.zero).animate(completeAnim),
                  child: FadeTransition(
                    opacity: completeAnim,
                    child: ScaleTransition(
                      scale: completeAnim,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: FloatingActionButton.extended(
                          heroTag: 'completeFab',
                          onPressed: () {
                            _toggleFAB();
                            _bulkComplete();
                          },
                          label: const Text('Complete all'),
                          icon: const Icon(Icons.done_all),
                          backgroundColor: Colors.blueGrey,
                        ),
                      ),
                    ),
                  ),
                ),

                // Add FAB (child)
                SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.9), end: Offset.zero).animate(addAnim),
                  child: FadeTransition(
                    opacity: addAnim,
                    child: ScaleTransition(
                      scale: addAnim,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: FloatingActionButton(
                          heroTag: 'addFab',
                          onPressed: () {
                            _toggleFAB();
                            _openAddDialog();
                          },
                          backgroundColor: segEmerald,
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ),
                  ),
                ),

                // Main FAB (toggle) - rotates while animating
                AnimatedBuilder(
                  animation: _fabController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _fabController.value * (math.pi / 4),
                      child: FloatingActionButton(
                        heroTag: 'mainFab',
                        backgroundColor: segEmerald,
                        onPressed: _toggleFAB,
                        child: Icon(_fabExpanded ? Icons.close : Icons.menu, color: Colors.white),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
