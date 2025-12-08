// lib/user/user_budget.dart
// Read-only budget view for regular users
// Corrected: SideTitleWidget usage uses only `meta` (no axisSide param)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class UserBudgetPage extends StatefulWidget {
  const UserBudgetPage({super.key});

  @override
  State<UserBudgetPage> createState() => _UserBudgetPageState();
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
  TransactionModel({
    required this.id,
    required this.description,
    required this.category,
    required this.amount,
    required this.type,
    required this.date,
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

class _UserBudgetPageState extends State<UserBudgetPage> with SingleTickerProviderStateMixin {
  List<Category> categories = [];
  List<TransactionModel> transactions = [];
  List<TicketEvent> tickets = [];

  late TabController _tabController;

  bool _showMoreOverview = false;
  bool _showMoreCategories = false;
  bool _showMoreTransactions = false;
  bool _showMoreTickets = false;
  bool _isLoading = false;

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
    _loadBudgetData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double get totalFunds => transactions.where((t) => t.type == 'income').fold(0.0, (a, b) => a + b.amount);
  double get totalExpenses => transactions.where((t) => t.type == 'expense').fold(0.0, (a, b) => a + b.amount);
  double get balance => totalFunds - totalExpenses;
  double get savingsRate => (totalFunds > 0) ? (balance / (totalFunds == 0 ? 1 : totalFunds)) * 100 : 0;

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
        categories = (data['categories'] as List).map((c) =>
            Category(
              id: c['id'].toString(),
              name: c['name'],
              budget: (c['budget'] as num).toDouble(),
            )
        ).toList();

        transactions = (data['transactions'] as List).map((t) =>
            TransactionModel(
              id: t['id'].toString(),
              description: t['description'],
              category: t['category'],
              amount: (t['amount'] as num).toDouble(),
              type: t['type'],
              date: DateTime.parse(t['date']),
            )
        ).toList();

        tickets = (data['tickets'] as List).map((ticket) =>
            TicketEvent(
              id: ticket['id'].toString(),
              event: ticket['event'],
              totalTickets: ticket['total_tickets'],
              price: (ticket['price'] as num).toDouble(),
              sales: (ticket['sales'] as List).map((s) =>
                  TicketSale(
                    buyer: s['buyer'],
                    qty: s['qty'],
                    date: DateTime.parse(s['date']),
                  )
              ).toList(),
            )
        ).toList();

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading budget: $e')),
      );
    }
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

  /// Bar chart with deterministic ticks to avoid overlapping axis labels.
  BarChartData _buildBarData() {
    // months labels (6 months)
    final months = List.generate(6, (idx) {
      final d = DateTime(DateTime.now().year, DateTime.now().month - (5 - idx), 1);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });

    // accumulate income and expense per month
    final income = List<double>.filled(6, 0);
    final expense = List<double>.filled(6, 0);

    void addMonthValue(String dateKey, double amount, List<double> target) {
      final idx = months.indexOf(dateKey);
      if (idx >= 0) target[idx] += amount;
    }

    for (var t in transactions) {
      final key = t.date.toIso8601String().substring(0, 7);
      if (t.type == 'income') addMonthValue(key, t.amount, income);
      if (t.type == 'expense') addMonthValue(key, t.amount, expense);
    }

    // Find the highest single-bar value among income and expense
    double highest = 0;
    for (int i = 0; i < 6; i++) {
      highest = math.max(highest, income[i]);
      highest = math.max(highest, expense[i]);
    }

    // If highest is 0, avoid division by zero — set a small default
    if (highest <= 0) highest = 1000;

    // Compute a 'nice' step that yields 3 intervals (0..3*step)
    double rawStep = highest / 3.0;
    double magnitude;
    if (rawStep <= 0) {
      magnitude = 1000;
    } else {
      magnitude = math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
    }
    if (magnitude <= 0) magnitude = 1000;

    final multipliers = [1, 2, 5];
    double best = multipliers.first * magnitude;
    double bestDiff = (best - rawStep).abs();
    for (var m in multipliers) {
      final cand = m * magnitude;
      final diff = (cand - rawStep).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = cand;
      }
    }
    double step = best;
    if (step < rawStep * 0.5) step *= 2;

    double t0 = 0;
    double t1 = step;
    double t2 = step * 2;
    double t3 = step * 3;
    if (t3 < highest) {
      final scale = (highest / t3).ceilToDouble();
      t1 *= scale;
      t2 *= scale;
      t3 *= scale;
    }

    final ticks = [t0, t1, t2, t3];

    String _formatValue(double v) {
      final val = v.round();
      if (val >= 1000) {
        final k = val / 1000;
        if (k == k.roundToDouble()) {
          return '${k.toInt()}K';
        } else {
          return '${k.toStringAsFixed(1)}K';
        }
      }
      return val.toString();
    }

    return BarChartData(
      groupsSpace: 12,
      barGroups: List.generate(6, (i) {
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(toY: income[i], width: 8, color: emeraldEnd),
            BarChartRodData(toY: expense[i], width: 8, color: Colors.redAccent),
          ],
        );
      }),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 48, // increase reserved size to avoid clipping
            getTitlesWidget: (value, meta) {
              // show only our ticks — allow small tolerance
              const double epsFactor = 0.12; // tolerance fraction
              for (var t in ticks) {
                final tol = math.max(1.0, t * epsFactor);
                if ((value - t).abs() <= tol) {
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      _formatValue(t),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
              final label = DateTime.parse(months[idx] + '-01').month.toString().padLeft(2, '0');
              return SideTitleWidget(
                meta: meta,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(label, style: const TextStyle(fontSize: 10)),
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(show: true, checkToShowHorizontalLine: _showEveryGridLine),
      borderData: FlBorderData(show: false),
      // make sure maxY covers top tick
      maxY: ticks.last * 1.05,
      barTouchData: BarTouchData(enabled: true),
    );
  }

  // helper used for grid display - show grid lines at our chosen ticks
  static bool _showEveryGridLine(double value) {
    // keep grid lines visible; label placement is handled in getTitlesWidget.
    return true;
  }

  Color _randomColorForKey(String key) {
    final colors = [const Color(0xFFF59E0B), emeraldEnd, accentPurple, const Color(0xFF3B82F6)];
    return colors[key.hashCode % colors.length];
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 8))],
    );
  }

  Widget _panelTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10.0, top: 8),
        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // FIXED: No overflow stat pill
  Widget _statPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _categoryRow(String title, double used, double budget, double ratio) {
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 6),
            Text(
              'Budget: ₱${budget.toStringAsFixed(0)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              child: Text(
                '₱${used.toStringAsFixed(0)} / ₱${budget.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${(ratio * 100).toStringAsFixed(1)}% of budget used',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              color: ratio > 1.0 ? Colors.red : emeraldEnd,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Budget Overview', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 120),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: emeraldStart.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: emeraldStart.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.visibility, size: 16, color: emeraldStart),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'View Only',
                        style: TextStyle(
                          color: emeraldStart,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: false, // non-scrollable so tabs evenly fill width
              labelColor: emeraldEnd,
              unselectedLabelColor: Colors.grey,
              indicatorColor: emeraldEnd,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: EdgeInsets.zero,
              labelPadding: EdgeInsets.zero,
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
      body: SafeArea(
        bottom: true,
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
    );
  }

  Widget _buildOverviewTab() {
    final spent = spentByCategory();
    final topCategories = spent.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final displayCategories = _showMoreOverview ? topCategories : topCategories.take(3).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _statPill('Total Funds', '₱${totalFunds.toStringAsFixed(2)}'),
              _statPill('Total Expenses', '₱${totalExpenses.toStringAsFixed(2)}'),
              _statPill('Balance', '₱${balance.toStringAsFixed(2)}'),
              _statPill('Ticket Revenue', '₱${ticketRevenue.toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            constraints: const BoxConstraints(minHeight: 300),
            decoration: _panelDecoration(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _panelTitle('Spending by Category'),
                if (spent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No expense data yet', style: TextStyle(color: Colors.grey)),
                  )
                else
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: _buildPieSections(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: spent.entries.map((e) {
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _randomColorForKey(e.key),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              e.key,
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Container(
            constraints: const BoxConstraints(minHeight: 280),
            decoration: _panelDecoration(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _panelTitle('6-Month Trend'),
                SizedBox(
                  height: 200,
                  child: BarChart(_buildBarData()),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 12, height: 12, color: emeraldEnd),
                        const SizedBox(width: 6),
                        const Text('Income', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 12, height: 12, color: Colors.redAccent),
                        const SizedBox(width: 6),
                        const Text('Expense', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Container(
            decoration: _panelDecoration(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _panelTitle('Top Spending Categories'),
                ...displayCategories.map((entry) {
                  final cat = categories.firstWhere((c) => c.name == entry.key, orElse: () => Category(id: '', name: entry.key, budget: 0));
                  final ratio = cat.budget > 0 ? entry.value / cat.budget : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                entry.key,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '₱${entry.value.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: Colors.grey[200],
                          color: ratio > 1.0 ? Colors.red : emeraldEnd,
                        ),
                      ],
                    ),
                  );
                }),
                if (topCategories.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextButton(
                      onPressed: () => setState(() => _showMoreOverview = !_showMoreOverview),
                      child: Text(_showMoreOverview ? 'Show Less' : 'Show More'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab() {
    final spent = spentByCategory();
    final displayCategories = _showMoreCategories ? categories : categories.take(5).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: emeraldStart.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: emeraldStart.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: emeraldStart, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This is a read-only view. Contact admin to modify budgets.',
                    style: TextStyle(color: emeraldStart, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Budget Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...displayCategories.map((c) {
            final used = spent[c.name] ?? 0.0;
            final ratio = c.budget > 0 ? used / c.budget : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _categoryRow(c.name, used, c.budget, ratio),
            );
          }),
          if (categories.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 20),
              child: Center(
                child: TextButton(
                  onPressed: () => setState(() => _showMoreCategories = !_showMoreCategories),
                  child: Text(_showMoreCategories ? 'Show Less' : 'Show More'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    final displayTransactions = _showMoreTransactions ? transactions : transactions.take(10).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: const [
              Expanded(
                child: Text(
                  'Recent Transactions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: transactions.isEmpty
              ? const Center(child: Text('No transactions yet', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: displayTransactions.length + (transactions.length > 10 ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == displayTransactions.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: TextButton(
                            onPressed: () => setState(() => _showMoreTransactions = !_showMoreTransactions),
                            child: Text(_showMoreTransactions ? 'Show Less' : 'Show More (${transactions.length - 10} more)'),
                          ),
                        ),
                      );
                    }

                    final tx = displayTransactions[index];
                    final isIncome = tx.type == 'income';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: isIncome ? emeraldEnd : Colors.redAccent,
                          child: Icon(
                            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          tx.description,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        subtitle: Text(
                          '${tx.category} • ${tx.date.toIso8601String().substring(0, 10)}',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        trailing: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            '${isIncome ? '+' : '-'}₱${tx.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isIncome ? emeraldEnd : Colors.redAccent,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTicketsTab() {
    final displayTickets = _showMoreTickets ? tickets : tickets.take(5).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: const [
              Expanded(
                child: Text(
                  'Ticket Events',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: tickets.isEmpty
              ? const Center(child: Text('No ticket events yet', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: displayTickets.length + (tickets.length > 5 ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == displayTickets.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: TextButton(
                            onPressed: () => setState(() => _showMoreTickets = !_showMoreTickets),
                            child: Text(_showMoreTickets ? 'Show Less' : 'Show More'),
                          ),
                        ),
                      );
                    }

                    final ev = displayTickets[index];
                    final sold = ev.sales.fold<int>(0, (s, sale) => s + sale.qty);
                    final revenue = sold * ev.price;
                    final soldRatio = ev.totalTickets > 0 ? (sold / ev.totalTickets).clamp(0.0, 1.0) : 0.0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ev.event,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Price: ₱${ev.price.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Sold: $sold / ${ev.totalTickets}',
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Revenue: ₱${revenue.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: emeraldEnd),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: CircularProgressIndicator(
                                    value: soldRatio,
                                    backgroundColor: Colors.grey[200],
                                    color: emeraldEnd,
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
        ),
      ],
    );
  }
}
