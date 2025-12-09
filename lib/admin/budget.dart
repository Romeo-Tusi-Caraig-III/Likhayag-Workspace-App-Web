// lib/admin/budget_dashboard.dart
// Enhanced Budget Dashboard with Smart FAB System

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import 'dart:math' as math;

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class Category {
  String id;
  String name;
  double budget;
  Category({required this.id, required this.name, required this.budget});
}

class TransactionModel {
  String id;
  String description;
  String category;
  double amount;
  String type;
  DateTime date;
  String? receipt;
  
  TransactionModel({
    required this.id,
    required this.description,
    required this.category,
    required this.amount,
    required this.type,
    required this.date,
    this.receipt,
  });
}

class TicketEvent {
  String id;
  String event;
  int totalTickets;
  double price;
  List<TicketSale> sales;
  
  TicketEvent({
    required this.id,
    required this.event,
    required this.totalTickets,
    required this.price,
    required this.sales,
  });
}

class TicketSale {
  String buyer;
  int qty;
  DateTime date;
  TicketSale({required this.buyer, required this.qty, required this.date});
}

class _BudgetPageState extends State<BudgetPage> with SingleTickerProviderStateMixin {
  List<Category> categories = [];
  List<TransactionModel> transactions = [];
  List<TicketEvent> tickets = [];

  late TabController _tabController;
  late AnimationController _fabController;
  final Map<String, TextEditingController> _budgetControllers = {};

  bool _showMoreOverview = false;
  bool _showMoreCategories = false;
  bool _showMoreTransactions = false;
  bool _showMoreTickets = false;
  bool _isLoading = false;
  bool _fabExpanded = false;

  String _transactionSearch = '';
  final TextEditingController _searchCtl = TextEditingController();

  static const Color emeraldStart = Color(0xFF10B981);
  static const Color emeraldEnd = Color(0xFF059669);
  static const Color accentPurple = Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _loadBudgetData();
  }

  @override
  void dispose() {
    for (var ctl in _budgetControllers.values) {
      ctl.dispose();
    }
    _searchCtl.dispose();
    _tabController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  double get totalFunds => transactions.where((t) => t.type == 'income').fold(0.0, (a, b) => a + b.amount);
  double get totalExpenses => transactions.where((t) => t.type == 'expense').fold(0.0, (a, b) => a + b.amount);
  double get balance => totalFunds - totalExpenses;

  double get ticketRevenue {
    double sum = 0;
    for (var ev in tickets) {
      final sold = ev.sales.fold<int>(0, (s, sale) => s + sale.qty);
      sum += sold * ev.price;
    }
    return sum;
  }

  Map<String, double> spentByCategory() {
    final map = <String, double>{};
    for (var c in categories) {
      map[c.name] = 0.0;
    }
    for (var t in transactions) {
      if (t.type == 'expense' && map.containsKey(t.category)) {
        map[t.category] = map[t.category]! + t.amount;
      }
    }
    return map;
  }

  Future<void> _loadBudgetData() async {
    setState(() => _isLoading = true);

    try {
      final data = await ApiService.getBudgetData();

      if (!mounted) return;

      setState(() {
        categories = (data['categories'] as List).map((c) => Category(
              id: c['id'].toString(),
              name: c['name'],
              budget: (c['budget'] as num).toDouble(),
            )).toList();

        transactions = (data['transactions'] as List).map((t) => TransactionModel(
              id: t['id'].toString(),
              description: t['description'],
              category: t['category'],
              amount: (t['amount'] as num).toDouble(),
              type: t['type'],
              date: DateTime.parse(t['date']),
              receipt: t['receipt'],
            )).toList();

        tickets = (data['tickets'] as List).map((ticket) => TicketEvent(
              id: ticket['id'].toString(),
              event: ticket['event'],
              totalTickets: ticket['total_tickets'],
              price: (ticket['price'] as num).toDouble(),
              sales: (ticket['sales'] as List).map((s) => TicketSale(
                    buyer: s['buyer'],
                    qty: s['qty'],
                    date: DateTime.parse(s['date']),
                  )).toList(),
            )).toList();

        for (var c in categories) {
          _budgetControllers[c.id] = TextEditingController(text: c.budget.toStringAsFixed(0));
        }

        final removedKeys = _budgetControllers.keys.where((k) => categories.indexWhere((c) => c.id == k) == -1).toList();
        for (var k in removedKeys) {
          _budgetControllers.remove(k)?.dispose();
        }
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error loading budget: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    await _loadBudgetData();
    if (!mounted) return;
    _showSnack('Budget data refreshed');
  }

  Future<void> _createTransaction(TransactionModel transaction) async {
    try {
      final result = await ApiService.createTransaction(
        type: transaction.type,
        category: transaction.category,
        description: transaction.description,
        amount: transaction.amount,
        date: transaction.date.toIso8601String(),
      );

      if (result['success'] == true) {
        await _loadBudgetData();
        if (!mounted) return;
        _showSnack('Transaction recorded successfully');
      } else {
        _showSnack(result['message'] ?? 'Failed to create transaction', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e', isError: true);
    }
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

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : emeraldEnd,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  void _showTransactionDetails(TransactionModel transaction) {
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
                    color: transaction.type == 'income' 
                        ? emeraldEnd.withOpacity(0.1) 
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    transaction.type == 'income' ? Icons.arrow_downward : Icons.arrow_upward,
                    color: transaction.type == 'income' ? emeraldEnd : Colors.red,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.description,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        transaction.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: transaction.type == 'income' ? emeraldEnd : Colors.red,
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
              icon: Icons.attach_money,
              label: 'Amount',
              value: '₱${transaction.amount.toStringAsFixed(2)}',
              valueColor: transaction.type == 'income' ? emeraldEnd : Colors.red,
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.category,
              label: 'Category',
              value: transaction.category,
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.calendar_today,
              label: 'Date',
              value: _formatDate(transaction.date),
            ),
            if (transaction.receipt != null) ...[
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.receipt_long,
                label: 'Receipt',
                value: 'Available',
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Delete Transaction?'),
                          content: const Text('This action cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        setState(() => transactions.removeWhere((t) => t.id == transaction.id));
                        _showSnack('Transaction deleted');
                      }
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
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

  void _openAddTransactionDialog() {
    _toggleFAB();
    
    final descCtl = TextEditingController();
    final amountCtl = TextEditingController();
    String type = 'expense';
    String category = categories.isNotEmpty ? categories.first.name : 'General';
    DateTime date = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final mq = MediaQuery.of(sheetContext);
        return Padding(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, -6))],
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: StatefulBuilder(builder: (contextSB, setStateSB) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Add Transaction',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [emeraldStart, emeraldEnd]),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 20),
                              onPressed: () => Navigator.pop(sheetContext),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: descCtl,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: type,
                        isExpanded: true,
                        items: ['expense', 'income'].map((e) => DropdownMenuItem(
                          value: e, 
                          child: Text(e[0].toUpperCase() + e.substring(1))
                        )).toList(),
                        onChanged: (v) => setStateSB(() => type = v ?? 'expense'),
                        decoration: InputDecoration(
                          labelText: 'Type',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: category,
                        isExpanded: true,
                        items: categories.map((c) => DropdownMenuItem(
                          value: c.name, 
                          child: Text(c.name)
                        )).toList(),
                        onChanged: (v) => setStateSB(() => category = v ?? (categories.isNotEmpty ? categories.first.name : 'General')),
                        decoration: InputDecoration(
                          labelText: 'Category',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountCtl,
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          prefixText: '₱',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: contextSB,
                            initialDate: date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setStateSB(() => date = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: emeraldEnd),
                              const SizedBox(width: 12),
                              Text(
                                'Date: ${_formatDate(date)}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _GradientButton(
                              onPressed: () async {
                                final amt = double.tryParse(amountCtl.text) ?? 0.0;
                                if (amt <= 0) {
                                  _showSnack('Please enter a valid amount', isError: true);
                                  return;
                                }

                                Navigator.pop(sheetContext);

                                await _createTransaction(TransactionModel(
                                  id: UniqueKey().toString(),
                                  description: descCtl.text.isEmpty ? 'Transaction' : descCtl.text,
                                  category: category,
                                  amount: amt,
                                  type: type,
                                  date: date,
                                ));
                              },
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openAddCategoryDialog() {
    _toggleFAB();
    
    final nameCtl = TextEditingController();
    final budgetCtl = TextEditingController(text: '1000');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: budgetCtl,
                decoration: const InputDecoration(
                  labelText: 'Monthly Budget',
                  prefixText: '₱',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            _GradientButton(
              onPressed: () {
                final name = nameCtl.text.trim();
                if (name.isEmpty) {
                  _showSnack('Category name is required', isError: true);
                  return;
                }
                final budget = double.tryParse(budgetCtl.text) ?? 0.0;
                setState(() {
                  categories.add(Category(id: UniqueKey().toString(), name: name, budget: budget));
                });
                Navigator.pop(ctx);
                _showSnack('Category added');
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _openAddEventDialog() {
    _toggleFAB();
    
    final nameCtl = TextEditingController();
    final ticketsCtl = TextEditingController(text: '100');
    final priceCtl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Ticket Event'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(
                  labelText: 'Event Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceCtl,
                decoration: const InputDecoration(
                  labelText: 'Price per Ticket',
                  prefixText: '₱',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ticketsCtl,
                decoration: const InputDecoration(
                  labelText: 'Total Tickets',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            _GradientButton(
              onPressed: () {
                final name = nameCtl.text.isEmpty ? 'Event' : nameCtl.text;
                final price = double.tryParse(priceCtl.text) ?? 0.0;
                final total = int.tryParse(ticketsCtl.text) ?? 0;
                setState(() {
                  tickets.add(TicketEvent(
                    id: UniqueKey().toString(),
                    event: name,
                    totalTickets: total,
                    price: price,
                    sales: [],
                  ));
                });
                Navigator.pop(ctx);
                _showSnack('Event added');
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSmartFAB() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Add Event button
        AnimatedOpacity(
          opacity: _fabExpanded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: _fabExpanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SmallFAB(
                    onPressed: _openAddEventDialog,
                    icon: Icons.confirmation_number,
                    label: 'Add Event',
                    heroTag: 'event',
                  ),
                )
              : const SizedBox.shrink(),
        ),
        
        // Add Category button
        AnimatedOpacity(
          opacity: _fabExpanded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: _fabExpanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SmallFAB(
                    onPressed: _openAddCategoryDialog,
                    icon: Icons.category,
                    label: 'Add Category',
                    heroTag: 'category',
                  ),
                )
              : const SizedBox.shrink(),
        ),
        
        // Add Transaction button
        AnimatedOpacity(
          opacity: _fabExpanded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: _fabExpanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SmallFAB(
                    onPressed: _openAddTransactionDialog,
                    icon: Icons.add,
                    label: 'Add Transaction',
                    heroTag: 'transaction',
                  ),
                )
              : const SizedBox.shrink(),
        ),
        
        // Main FAB
        FloatingActionButton(
          onPressed: _toggleFAB,
          backgroundColor: emeraldStart,
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

  List<PieChartSectionData> _buildPieSections() {
    final map = spentByCategory();
    final colors = [accentPurple, emeraldEnd, const Color(0xFFF59E0B), const Color(0xFFEF4444), const Color(0xFF3B82F6)];
    final total = map.values.fold(0.0, (a, b) => a + b);
    int i = 0;
    return map.entries.map((e) {
      final v = e.value;
      final pct = total == 0 ? 0.0 : (v / total) * 100;
      final section = PieChartSectionData(
        color: colors[i % colors.length],
        value: v,
        title: pct > 0 ? '${pct.toStringAsFixed(0)}%' : '',
        radius: 48,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
      i++;
      return section;
    }).toList();
  }

  BarChartData _buildBarData() {
    final months = List.generate(6, (idx) {
      final d = DateTime(DateTime.now().year, DateTime.now().month - (5 - idx), 1);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });
    final income = List<double>.filled(6, 0);
    final expense = List<double>.filled(6, 0);

    for (var t in transactions) {
      final key = t.date.toIso8601String().substring(0, 7);
      final idx = months.indexOf(key);
      if (idx >= 0) {
        if (t.type == 'income') {
          income[idx] += t.amount;
        } else {
          expense[idx] += t.amount;
        }
      }
    }

    return BarChartData(
      groupsSpace: 12,
      barGroups: List.generate(6, (i) {
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(toY: income[i], width: 8, color: emeraldEnd, borderRadius: BorderRadius.circular(4)),
            BarChartRodData(toY: expense[i], width: 8, color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
          ],
        );
      }),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
              final label = months[idx].substring(5);
              return SideTitleWidget(meta: meta, child: Text(label, style: const TextStyle(fontSize: 10)));
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(show: true),
      borderData: FlBorderData(show: false),
    );
  }

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: emeraldEnd),
              const SizedBox(height: 16),
              const Text('Loading budget data...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final statsMap = {
      'Total Funds': '₱${totalFunds.toStringAsFixed(2)}',
      'Total Expenses': '₱${totalExpenses.toStringAsFixed(2)}',
      'Balance': '₱${balance.toStringAsFixed(2)}',
      'Ticket Revenue': '₱${ticketRevenue.toStringAsFixed(2)}',
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Budget Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: emeraldEnd,
              unselectedLabelColor: Colors.grey,
              indicatorColor: emeraldEnd,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Categories'),
                Tab(text: 'Transactions'),
                Tab(text: 'Tickets'),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            top: false,
            child: Column(
              children: [
                // Stats cards
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: LayoutBuilder(builder: (ctx, constraints) {
                    final width = constraints.maxWidth;
                    final singleRow = width >= 420;
                    final spacing = 12.0;
                    
                    if (singleRow) {
                      return Row(
                        children: [
                          Expanded(child: _StatCard('Total Funds', statsMap['Total Funds']!, Colors.blue.shade400)),
                          SizedBox(width: spacing),
                          Expanded(child: _StatCard('Total Expenses', statsMap['Total Expenses']!, Colors.red.shade400)),
                          SizedBox(width: spacing),
                          Expanded(child: _StatCard('Balance', statsMap['Balance']!, Colors.green.shade400)),
                          SizedBox(width: spacing),
                          Expanded(child: _StatCard('Ticket Revenue', statsMap['Ticket Revenue']!, Colors.orange.shade400)),
                        ],
                      );
                    } else {
                      final itemWidth = (width - spacing) / 2;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          SizedBox(width: itemWidth, child: _StatCard('Total Funds', statsMap['Total Funds']!, Colors.blue.shade400)),
                          SizedBox(width: itemWidth, child: _StatCard('Total Expenses', statsMap['Total Expenses']!, Colors.red.shade400)),
                          SizedBox(width: itemWidth, child: _StatCard('Balance', statsMap['Balance']!, Colors.green.shade400)),
                          SizedBox(width: itemWidth, child: _StatCard('Ticket Revenue', statsMap['Ticket Revenue']!, Colors.orange.shade400)),
                        ],
                      );
                    }
                  }),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildCategoriesTab(),
                      _buildTransactionsTab(),
                      _buildTicketsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Overlay when FAB is expanded
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

  Widget _buildOverviewTab() {
    final spent = spentByCategory();
    final topCategories = spent.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final displayCategories = _showMoreOverview ? topCategories : topCategories.take(3).toList();

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: emeraldEnd,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 8))],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Spending by Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (spent.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: Text('No expense data yet', style: TextStyle(color: Colors.grey))),
                    )
                  else
                    SizedBox(
                      height: 200,
                      child: PieChart(PieChartData(sections: _buildPieSections(), sectionsSpace: 2, centerSpaceRadius: 40)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 8))],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('6-Month Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(height: 220, child: BarChart(_buildBarData())),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 16, height: 16, color: emeraldEnd),
                      const SizedBox(width: 6),
                      const Text('Income', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 16),
                      Container(width: 16, height: 16, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      const Text('Expense', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: emeraldEnd,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: categories.length + 1,
        itemBuilder: (context, index) {
          if (index == categories.length) {
            return const SizedBox(height: 80);
          }
          
          final c = categories[index];
          final spent = spentByCategory();
          final used = spent[c.name] ?? 0.0;
          final ratio = c.budget > 0 ? used / c.budget : 0.0;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Text('Delete Category?'),
                              content: Text('Delete "${c.name}"? Past transactions won\'t be deleted.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            setState(() {
                              categories.removeWhere((x) => x.id == c.id);
                              _budgetControllers.remove(c.id)?.dispose();
                            });
                            _showSnack('Category deleted');
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('₱${used.toStringAsFixed(0)} / ₱${c.budget.toStringAsFixed(0)}'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    color: ratio > 1.0 ? Colors.red : emeraldEnd,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionsTab() {
    final filtered = _transactionSearch.isEmpty
        ? transactions
        : transactions.where((t) => 
            t.description.toLowerCase().contains(_transactionSearch.toLowerCase()) || 
            t.category.toLowerCase().contains(_transactionSearch.toLowerCase())
          ).toList();

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: emeraldEnd,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtl,
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _transactionSearch.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtl.clear();
                          setState(() => _transactionSearch = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _transactionSearch = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _transactionSearch.isEmpty ? 'No transactions yet' : 'No matches found',
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length + 1,
                    itemBuilder: (context, index) {
                      if (index == filtered.length) {
                        return const SizedBox(height: 80);
                      }

                      final tx = filtered[index];
                      final isIncome = tx.type == 'income';
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ListTile(
                          onTap: () => _showTransactionDetails(tx),
                          leading: CircleAvatar(
                            backgroundColor: isIncome ? emeraldEnd : Colors.redAccent,
                            child: Icon(
                              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(tx.description, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${tx.category} • ${_formatDate(tx.date)}'),
                          trailing: Text(
                            '₱${tx.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isIncome ? emeraldEnd : Colors.redAccent,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketsTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: emeraldEnd,
      child: tickets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.confirmation_number, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No ticket events yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tickets.length + 1,
              itemBuilder: (context, index) {
                if (index == tickets.length) {
                  return const SizedBox(height: 80);
                }

                final ev = tickets[index];
                final sold = ev.sales.fold<int>(0, (s, sale) => s + sale.qty);
                final revenue = sold * ev.price;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                ev.event,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: const Text('Delete Event?'),
                                    content: const Text('This will delete all sales data.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  setState(() => tickets.removeWhere((t) => t.id == ev.id));
                                  _showSnack('Event deleted');
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Price: ₱${ev.price.toStringAsFixed(2)}'),
                                  const SizedBox(height: 4),
                                  Text('Sold: $sold / ${ev.totalTickets}'),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Revenue: ₱${revenue.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: emeraldEnd),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 50,
                              height: 50,
                              child: CircularProgressIndicator(
                                value: ev.totalTickets > 0 ? sold / ev.totalTickets : 0.0,
                                backgroundColor: Colors.grey.shade200,
                                color: emeraldEnd,
                                strokeWidth: 6,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// Helper Widgets
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      ),
    );
  }
}

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
      foregroundColor: const Color(0xFF059669),
      elevation: 3,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
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
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              child: child,
            ),
          ),
        ),
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
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF059669)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}