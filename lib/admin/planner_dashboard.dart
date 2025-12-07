// lib/admin/planner_dashboard.dart
// Complete Planner page with Supabase integration

import 'dart:convert';
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

class _PlannerHomePage extends State<PlannerPage> {
  final List<Task> tasks = [];
  String currentTab = 'all';
  String search = '';
  bool timelineView = true;
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

  final Map<String, GlobalKey> _segKeys = {
    'all': GlobalKey(),
    'pending': GlobalKey(),
    'completed': GlobalKey(),
    'high': GlobalKey(),
  };

  static const Color segEmerald = Color(0xFF059669);
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

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: Duration(seconds: 2)));
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
              color: Color(0xFFF7F3FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(_editingId == null ? 'Add Task' : 'Edit Task',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(ctx),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(color: Color(0xFF059669), shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _titleCtl,
                          decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _type,
                                decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(value: 'assignment', child: Text('Assignment')),
                                  DropdownMenuItem(value: 'study', child: Text('Study')),
                                  DropdownMenuItem(value: 'project', child: Text('Project')),
                                  DropdownMenuItem(value: 'exam', child: Text('Exam')),
                                ],
                                onChanged: (v) => _type = v ?? 'assignment',
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 140,
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
                                ),
                                icon: const Icon(Icons.calendar_today, size: 16),
                                label: Text(_dueDateCtl.text.isEmpty ? 'Pick' : _dueDateCtl.text,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _priority,
                          decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'low', child: Text('Low')),
                            DropdownMenuItem(value: 'medium', child: Text('Medium')),
                            DropdownMenuItem(value: 'high', child: Text('High')),
                          ],
                          onChanged: (v) => _priority = v ?? 'medium',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descCtl,
                          decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
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
        title: const Text('Delete task?'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await _deleteTaskApi(t.id);
  }

  Widget _taskCard(Task t) {
    final diff = daysDiff(t.dueDateIso);
    final overdue = diff < 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (t.desc.isNotEmpty) Text(t.desc, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _chip(t.type, Colors.grey.shade100),
                      _chip(t.priority, _priorityColor(t.priority)),
                      if (overdue)
                        Text('${diff.abs()}d overdue', style: const TextStyle(color: Colors.red))
                      else
                        Text('$diff d left', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: segEmerald),
                  onPressed: () => _openAddDialog(edit: t),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDelete(t),
                ),
                Checkbox(
                  value: t.completed,
                  onChanged: (v) => _updateTaskApi(t.id, {'completed': v ?? false}),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Color _priorityColor(String p) {
    if (p == 'high') return Colors.red.shade100;
    if (p == 'low') return Colors.green.shade100;
    return Colors.orange.shade100;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = getFilteredSorted();
    final stats = computeStats();
    final visible = _showMoreTasks ? filtered : filtered.take(_maxVisibleTasks).toList();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshTasks,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Planner', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    IconButton(
                      icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
                      onPressed: _isLoading ? null : _refreshTasks,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statTile('Pending', stats['pending']!),
                    _statTile('Completed', stats['completed']!),
                    _statTile('High', stats['high']!),
                    _statTile('Overdue', stats['overdue']!),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => search = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<SortBy>(
                      value: sortBy,
                      items: const [
                        DropdownMenuItem(value: SortBy.due, child: Text('Due')),
                        DropdownMenuItem(value: SortBy.priority, child: Text('Priority')),
                        DropdownMenuItem(value: SortBy.created, child: Text('Created')),
                      ],
                      onChanged: (v) => setState(() => sortBy = v!),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: ['all', 'pending', 'completed', 'high'].map((tab) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ElevatedButton(
                          onPressed: () => setState(() => currentTab = tab),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: currentTab == tab ? segEmerald : Colors.grey.shade200,
                            foregroundColor: currentTab == tab ? Colors.white : Colors.black,
                          ),
                          child: Text(tab[0].toUpperCase() + tab.substring(1)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                if (filtered.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No tasks found')))
                else
                  ...visible.map(_taskCard),
                if (filtered.length > _maxVisibleTasks)
                  TextButton(
                    onPressed: () => setState(() => _showMoreTasks = !_showMoreTasks),
                    child: Text(_showMoreTasks ? 'Show less' : 'Show more (${filtered.length - _maxVisibleTasks} more)'),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddDialog(),
        backgroundColor: segEmerald,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }

  Widget _statTile(String label, int value) {
    return Container(
      width: 80,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6EDF3)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 4),
          Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}