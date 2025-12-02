// lib/admin/budget_dashboard.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({Key? key}) : super(key: key);

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class Category {
  String id;
  String name;
  double budget;
  Category({required this.id, required this.name, required this.budget});
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'budget': budget};
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
  Map<String, dynamic> toMap() => {
        'id': id,
        'description': description,
        'category': category,
        'amount': amount,
        'type': type,
        'date': date.toIso8601String(),
      };
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
  Map<String, dynamic> toMap() => {
        'id': id,
        'event': event,
        'totalTickets': totalTickets,
        'price': price,
        'sales': sales.map((s) => s.toMap()).toList(),
      };
}

class TicketSale {
  String buyer;
  int qty;
  DateTime date;
  TicketSale({required this.buyer, required this.qty, required this.date});
  Map<String, dynamic> toMap() => {'buyer': buyer, 'qty': qty, 'date': date.toIso8601String()};
}

class _BudgetPageState extends State<BudgetPage> with SingleTickerProviderStateMixin {
  List<Category> categories = [
    Category(id: '1', name: 'Costume', budget: 3000),
    Category(id: '2', name: 'Equipment', budget: 5000),
    Category(id: '3', name: 'General', budget: 5000),
  ];

  List<TransactionModel> transactions = [
    TransactionModel(id: 't1', description: 'Cash', category: 'General', amount: 1000, type: 'expense', date: DateTime.now().subtract(const Duration(days: 1))),
    TransactionModel(id: 't2', description: 'GCash', category: 'General', amount: 5000, type: 'income', date: DateTime.now().subtract(const Duration(days: 2))),
    TransactionModel(id: 't3', description: 'Cash', category: 'Equipment', amount: 5000, type: 'expense', date: DateTime.now().subtract(const Duration(days: 3))),
    TransactionModel(id: 't4', description: 'Snack Sales', category: 'General', amount: 200, type: 'income', date: DateTime.now().subtract(const Duration(days: 4))),
    TransactionModel(id: 't5', description: 'Props', category: 'Costume', amount: 800, type: 'expense', date: DateTime.now().subtract(const Duration(days: 5))),
  ];

  List<TicketEvent> tickets = [
    TicketEvent(
      id: 'e1',
      event: 'Play Night',
      totalTickets: 200,
      price: 150.0,
      sales: [
        TicketSale(buyer: 'Alice', qty: 2, date: DateTime.now().subtract(const Duration(days: 2))),
        TicketSale(buyer: 'Bob', qty: 1, date: DateTime.now().subtract(const Duration(days: 1))),
        TicketSale(buyer: 'Charlie', qty: 3, date: DateTime.now().subtract(const Duration(days: 3))),
      ],
    ),
    TicketEvent(
      id: 'e2',
      event: 'Matinee',
      totalTickets: 120,
      price: 120.0,
      sales: [
        TicketSale(buyer: 'Dana', qty: 1, date: DateTime.now().subtract(const Duration(days: 4))),
      ],
    ),
  ];

  late TabController _tabController;
  final Map<String, TextEditingController> _budgetControllers = {};

  // show-more states per section
  bool _showMoreOverview = false;
  bool _showMoreCategories = false;
  bool _showMoreTransactions = false;
  bool _showMoreTickets = false;

  // user-provided two-tone emerald gradient
  static const Color emeraldStart = Color(0xFF10B981); // #10B981
  static const Color emeraldEnd = Color(0xFF059669); // #059669
  static const Color accentPurple = Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // add listener so IndexedStack updates when TabBar changes index
    _tabController.addListener(() {
      if (mounted) setState(() {}); // rebuild to show the appropriate IndexedStack child
    });

    for (var c in categories) {
      _budgetControllers[c.id] = TextEditingController(text: c.budget.toStringAsFixed(0));
    }
  }

  @override
  void dispose() {
    for (var ctl in _budgetControllers.values) ctl.dispose();
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
    for (var c in categories) map[c.name] = 0.0;
    for (var t in transactions) {
      if (t.type == 'expense' && map.containsKey(t.category)) {
        map[t.category] = map[t.category]! + t.amount;
      }
    }
    return map;
  }

  Future<void> _exportJson() async {
    try {
      final payload = {
        'categories': categories.map((c) => c.toMap()).toList(),
        'transactions': transactions.map((t) => t.toMap()).toList(),
        'tickets': tickets.map((e) => e.toMap()).toList(),
        'exportedAt': DateTime.now().toIso8601String(),
      };
      final raw = const JsonEncoder.withIndent('  ').convert(payload);
      await Clipboard.setData(ClipboardData(text: raw));
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exported JSON copied to clipboard')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  // --------------------------
  // Gradient button helpers
  // --------------------------
  Widget _gradientButton({required Widget child, required VoidCallback onPressed, EdgeInsets? padding, BorderRadius? borderRadius}) {
    final br = borderRadius ?? BorderRadius.circular(8);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [emeraldStart, emeraldEnd]),
          borderRadius: br,
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: br,
          child: Padding(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: DefaultTextStyle(style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), child: child),
          ),
        ),
      ),
    );
  }

  Widget _gradientButtonIcon({required IconData icon, required String label, required VoidCallback onPressed, EdgeInsets? padding}) {
    return _gradientButton(
      onPressed: onPressed,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  // Use for text-only actions (matching emerald color)
  ButtonStyle _textButtonStyle() {
    return TextButton.styleFrom(foregroundColor: emeraldEnd);
  }

  // --------------------------------

  void _openAddTransactionDialog() {
    final descCtl = TextEditingController();
    final amountCtl = TextEditingController();
    String type = 'expense';
    String category = categories.isNotEmpty ? categories.first.name : 'General';
    DateTime date = DateTime.now();

    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Add Transaction'),
            content: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  TextField(controller: descCtl, decoration: const InputDecoration(labelText: 'Description')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: type,
                    items: ['expense', 'income']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e[0].toUpperCase() + e.substring(1))))
                        .toList(),
                    onChanged: (v) => type = v ?? 'expense',
                    decoration: const InputDecoration(labelText: 'Type'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: category,
                    items: categories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                    onChanged: (v) => category = v ?? (categories.isNotEmpty ? categories.first.name : 'General'),
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: amountCtl, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Date: '),
                      TextButton(
                          style: _textButtonStyle(),
                          onPressed: () async {
                            final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                            if (picked != null) setState(() => date = picked);
                          },
                          child: Text('${date.toIso8601String().substring(0, 10)}')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('(Receipt upload not implemented in this demo)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), style: _textButtonStyle(), child: const Text('Cancel')),
              // Save gradient button
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _gradientButton(onPressed: () {
                  final amt = double.tryParse(amountCtl.text) ?? 0.0;
                  setState(() {
                    transactions.insert(
                        0,
                        TransactionModel(
                            id: UniqueKey().toString(),
                            description: descCtl.text.isEmpty ? 'Transaction' : descCtl.text,
                            category: category,
                            amount: amt,
                            type: type,
                            date: date));
                  });
                  Navigator.pop(ctx);
                }, child: const Text('Save')),
              ),
            ],
          );
        });
  }

  void _openAddEventDialog([TicketEvent? edit]) {
    final nameCtl = TextEditingController(text: edit?.event ?? '');
    final ticketsCtl = TextEditingController(text: edit?.totalTickets.toString() ?? '100');
    final priceCtl = TextEditingController(text: edit?.price.toString() ?? '0');

    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(edit == null ? 'Add Event' : 'Edit Event'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Event Name')),
                const SizedBox(height: 8),
                TextField(controller: priceCtl, decoration: const InputDecoration(labelText: 'Price (₱)'), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                TextField(controller: ticketsCtl, decoration: const InputDecoration(labelText: 'Total Tickets'), keyboardType: TextInputType.number),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), style: _textButtonStyle(), child: const Text('Cancel')),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _gradientButton(onPressed: () {
                  final name = nameCtl.text.isEmpty ? 'Event' : nameCtl.text;
                  final price = double.tryParse(priceCtl.text) ?? 0.0;
                  final total = int.tryParse(ticketsCtl.text) ?? 0;
                  setState(() {
                    if (edit != null) {
                      edit.event = name;
                      edit.price = price;
                      edit.totalTickets = total;
                    } else {
                      tickets.add(TicketEvent(id: UniqueKey().toString(), event: name, totalTickets: total, price: price, sales: []));
                    }
                  });
                  Navigator.pop(ctx);
                }, child: const Text('Save')),
              ),
            ],
          );
        });
  }

  void _openRecordSaleDialog(TicketEvent ev) {
    final buyerCtl = TextEditingController();
    final qtyCtl = TextEditingController(text: '1');
    DateTime date = DateTime.now();

    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text('Record Sale (${ev.event})'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: buyerCtl, decoration: const InputDecoration(labelText: 'Buyer Name')),
                const SizedBox(height: 8),
                TextField(controller: qtyCtl, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('Date: '),
                  TextButton(
                      style: _textButtonStyle(),
                      onPressed: () async {
                        final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (picked != null) setState(() => date = picked);
                      },
                      child: Text('${date.toIso8601String().substring(0, 10)}'))
                ])
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), style: _textButtonStyle(), child: const Text('Cancel')),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _gradientButton(onPressed: () {
                  final qty = int.tryParse(qtyCtl.text) ?? 1;
                  setState(() {
                    ev.sales.add(TicketSale(buyer: buyerCtl.text.isEmpty ? 'Buyer' : buyerCtl.text, qty: qty, date: date));
                  });
                  Navigator.pop(ctx);
                }, child: const Text('Save')),
              ),
            ],
          );
        });
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

    void addMonthValue(String date, double amount, List<double> target) {
      final key = date.substring(0, 7);
      final idx = months.indexOf(key);
      if (idx >= 0) target[idx] += amount;
    }

    for (var t in transactions) {
      final key = t.date.toIso8601String().substring(0, 7);
      if (t.type == 'income') addMonthValue(key, t.amount, income);
      if (t.type == 'expense') addMonthValue(key, t.amount, expense);
    }

    return BarChartData(
      groupsSpace: 12,
      barGroups: List.generate(6, (i) {
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(toY: income[i], width: 8),
            BarChartRodData(toY: expense[i], width: 8, color: Colors.redAccent),
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
                  return SideTitleWidget(axisSide: meta.axisSide, child: Text(label, style: const TextStyle(fontSize: 10)));
                }))),
      gridData: FlGridData(show: true),
      borderData: FlBorderData(show: false),
    );
  }

  Color _randomColorForKey(String key) {
    final colors = [const Color(0xFFF59E0B), emeraldEnd, accentPurple, const Color(0xFF3B82F6)];
    return colors[key.hashCode % colors.length];
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [
      BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 8))
    ]);
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

  Widget _statPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _categoryRow(String title, double used, double budget, double ratio, Category c) {
    final ctl = _budgetControllers.putIfAbsent(c.id, () => TextEditingController(text: c.budget.toStringAsFixed(0)));
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 520;
      final controls = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 120,
              child: TextFormField(
                controller: ctl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12)),
              ),
            ),
            // Update -> gradient
            _gradientButton(onPressed: () {
              setState(() {
                c.budget = double.tryParse(ctl.text) ?? c.budget;
              });
            }, child: const Text('Update')),
            // Delete (destructive) keep red
            OutlinedButton(
              onPressed: () {
                setState(() {
                  categories.removeWhere((x) => x.id == c.id);
                  _budgetControllers.remove(c.id)?.dispose();
                });
              },
              child: const Text('Delete'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              child: Text('₱${used.toStringAsFixed(0)} / ₱${budget.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );

      if (isNarrow) {
        return Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Set monthly budget', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 12),
                controls,
                const SizedBox(height: 10),
                Text('${(ratio * 100).toStringAsFixed(1)}% of budget used', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: ratio, minHeight: 10),
              ],
            ),
          ),
        );
      }

      return Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Set monthly budget', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ]),
              ),
              const SizedBox(width: 12),
              controls,
            ],
          ),
        ),
      );
    });
  }

  Widget _transactionRow(TransactionModel t) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.description, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('${t.category} • ${t.date.toIso8601String().substring(0, 10)}', style: const TextStyle(color: Colors.grey)),
          ])
        ]),
        Row(children: [
          Text(
            (t.type == 'expense' ? '- ' : '') + '₱${t.amount.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: t.type == 'expense' ? Colors.red : Colors.green),
          ),
          const SizedBox(width: 8),
          // Delete transaction -> red outlined
          OutlinedButton(
            onPressed: () => setState(() => transactions.removeWhere((x) => x.id == t.id)),
            child: const Text('Delete'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
          )
        ])
      ]),
    );
  }

  Widget _ticketStatTileSimple(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(color: const Color(0xFFF7F5FF), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // aesthetic "Show more" pill styled to match emerald gradient & soft shadow
  Widget _showMorePill({required bool expanded, required VoidCallback onTap}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [emeraldStart, emeraldEnd]),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [BoxShadow(color: emeraldEnd.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_tabController.index == 0 ? (_showMoreOverview ? Icons.expand_less : Icons.expand_more) : Icons.expand_more, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                expanded ? 'Show less' : 'Show more',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pieSections = _buildPieSections();
    final media = MediaQuery.of(context);

    // compact limits
    const overviewCategoryLimit = 2;
    const overviewTransactionsLimit = 3;
    const categoriesLimit = 3;
    const transactionsLimit = 4;
    const ticketsLimit = 1;
    const recentSalesLimit = 4;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.of(context).maybePop()),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {},
          onHorizontalDragUpdate: (_) {},
          onHorizontalDragEnd: (_) {},
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(18.0),
            child: Column(
              children: [
                // TOP CARD
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _panelDecoration(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: const [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Budget & Ticketing', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          SizedBox(height: 6),
                          Text('Manage budgets, transactions, and event revenue', style: TextStyle(color: Colors.grey)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    // action column
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Add Transaction -> gradient icon button
                            _gradientButtonIcon(icon: Icons.add, label: 'Add Transaction', onPressed: _openAddTransactionDialog),
                            const SizedBox(height: 10),
                            // Export JSON -> gradient icon button
                            _gradientButtonIcon(icon: Icons.file_download, label: 'Export JSON', onPressed: _exportJson),
                          ],
                        ),

                        const SizedBox(width: 12),

                        // Add Event -> gradient icon button
                        _gradientButtonIcon(icon: Icons.event, label: 'Add Event', onPressed: () => _openAddEventDialog()),

                        const Spacer(),
                      ],
                    ),

                    const SizedBox(height: 18),

                    LayoutBuilder(builder: (context, constraints) {
                      if (constraints.maxWidth >= 520) {
                        return Row(
                          children: [
                            Expanded(child: _statPill('Available Balance', '₱${balance.toStringAsFixed(2)}')),
                            const SizedBox(width: 12),
                            Expanded(child: _statPill('Total Expenses', '₱${totalExpenses.toStringAsFixed(2)}')),
                            const SizedBox(width: 12),
                            Expanded(child: _statPill('Savings Rate', '${savingsRate.toStringAsFixed(1)}%')),
                            const SizedBox(width: 12),
                            Expanded(child: _statPill('Ticket Revenue', '₱${ticketRevenue.toStringAsFixed(2)}')),
                          ],
                        );
                      }

                      return Column(children: [
                        Row(children: [
                          Expanded(child: _statPill('Available Balance', '₱${balance.toStringAsFixed(2)}')),
                          const SizedBox(width: 12),
                          Expanded(child: _statPill('Total Expenses', '₱${totalExpenses.toStringAsFixed(2)}')),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _statPill('Savings Rate', '${savingsRate.toStringAsFixed(1)}%')),
                          const SizedBox(width: 12),
                          Expanded(child: _statPill('Ticket Revenue', '₱${ticketRevenue.toStringAsFixed(2)}')),
                        ]),
                      ]);
                    }),
                  ]),
                ),

                const SizedBox(height: 14),

                // Tabs
                LayoutBuilder(builder: (context, tcon) {
                  final w = tcon.maxWidth;
                  double fontSize = 15;
                  double verticalPadding = 10;
                  double indicatorVPadding = 10;
                  if (w < 360) {
                    fontSize = 13;
                    verticalPadding = 8;
                    indicatorVPadding = 8;
                  } else if (w < 420) {
                    fontSize = 14;
                    verticalPadding = 9;
                    indicatorVPadding = 9;
                  }

                  return Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: verticalPadding * 3 + fontSize,
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: false,
                          indicatorPadding: EdgeInsets.symmetric(horizontal: 8, vertical: indicatorVPadding),
                          indicator: BoxDecoration(
                            gradient: const LinearGradient(colors: [emeraldStart, emeraldEnd]),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [BoxShadow(color: emeraldEnd.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 6))],
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: Colors.white,
                          unselectedLabelColor: emeraldEnd,
                          labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: fontSize),
                          unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: fontSize),
                          labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                          tabs: const [
                            Tab(child: FittedBox(child: Text('Overview'))),
                            Tab(child: FittedBox(child: Text('Categories'))),
                            Tab(child: FittedBox(child: Text('Transactions'))),
                            Tab(child: FittedBox(child: Text('Ticketing Sales'))),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 14),

                // main content
                LayoutBuilder(builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 920;

                  // LEFT: use IndexedStack to avoid unbounded height errors inside SingleChildScrollView
                  final left = IndexedStack(
                    index: _tabController.index,
                    children: [
                      // OVERVIEW — compact lists + "show more"
                      AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOut,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _panelTitle('Budget & Expenses'),

                          // categories (compact)
                          ..._buildOverviewCategories(overviewCategoryLimit, _showMoreOverview),

                          // show-more pill for overview categories if needed
                          if (categories.length > overviewCategoryLimit)
                            _showMorePill(
                              expanded: _showMoreOverview,
                              onTap: () => setState(() => _showMoreOverview = !_showMoreOverview),
                            ),

                          const SizedBox(height: 12),
                          _panelTitle('Recent Transactions'),

                          // transactions (compact)
                          ..._buildOverviewTransactions(overviewTransactionsLimit, _showMoreOverview),

                          if (transactions.length > overviewTransactionsLimit && !_showMoreOverview)
                            _showMorePill(
                              expanded: _showMoreOverview,
                              onTap: () => setState(() => _showMoreOverview = !_showMoreOverview),
                            ),
                        ]),
                      ),

                      // CATEGORIES tab
                      AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOut,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _panelTitle('Manage Categories'),
                          Container(
                              decoration: _panelDecoration(),
                              padding: const EdgeInsets.all(12),
                              child: Column(children: [
                                ..._buildCategoryList(categoriesLimit, _showMoreCategories),
                              ])),
                          if (categories.length > categoriesLimit)
                            _showMorePill(
                              expanded: _showMoreCategories,
                              onTap: () => setState(() => _showMoreCategories = !_showMoreCategories),
                            ),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: TextFormField(
                                decoration: const InputDecoration(labelText: 'New Category', border: OutlineInputBorder()),
                                onFieldSubmitted: (v) {
                                  if (v.trim().isEmpty) return;
                                  setState(() {
                                    final newC = Category(id: UniqueKey().toString(), name: v.trim(), budget: 0);
                                    categories.add(newC);
                                    _budgetControllers[newC.id] = TextEditingController(text: '0');
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(width: 120, child: TextFormField(decoration: const InputDecoration(labelText: 'Budget', border: OutlineInputBorder()), keyboardType: TextInputType.number, onFieldSubmitted: (v) {})),
                            const SizedBox(width: 10),
                            _gradientButton(onPressed: () {
                              setState(() {
                                final newC = Category(id: UniqueKey().toString(), name: 'New Category', budget: 0);
                                categories.add(newC);
                                _budgetControllers[newC.id] = TextEditingController(text: '0');
                              });
                            }, child: const Text('Add Category')),
                          ]),
                          const SizedBox(height: 12),
                        ]),
                      ),

                      // TRANSACTIONS tab
                      AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOut,
                        child: Column(children: [
                          _panelTitle('All Transactions'),
                          Container(
                              decoration: _panelDecoration(),
                              padding: const EdgeInsets.all(12),
                              child: Column(children: [
                                ..._buildTransactionsList(transactionsLimit, _showMoreTransactions),
                              ])),
                          if (transactions.length > transactionsLimit)
                            _showMorePill(
                              expanded: _showMoreTransactions,
                              onTap: () => setState(() => _showMoreTransactions = !_showMoreTransactions),
                            ),
                        ]),
                      ),

                      // TICKETING tab — compact and show-more for events / recent sales
                      AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOut,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _panelTitle('Ticketing Sales'),
                          Container(
                              decoration: _panelDecoration(),
                              padding: const EdgeInsets.all(12),
                              child: LayoutBuilder(builder: (context, constraints) {
                                if (constraints.maxWidth >= 520) {
                                  return Row(children: [
                                    Expanded(child: _ticketStatTileSimple('Total Tickets', tickets.fold<int>(0, (s, e) => s + e.totalTickets).toString())),
                                    const SizedBox(width: 8),
                                    Expanded(child: _ticketStatTileSimple('Tickets Sold', tickets.fold<int>(0, (s, e) => s + e.sales.fold<int>(0, (si, sale) => si + sale.qty)).toString())),
                                    const SizedBox(width: 8),
                                    Expanded(child: _ticketStatTileSimple('Tickets Remaining', (tickets.fold<int>(0, (s, e) => s + e.totalTickets) - tickets.fold<int>(0, (s, e) => s + e.sales.fold<int>(0, (si, sale) => si + sale.qty))).toString())),
                                    const SizedBox(width: 8),
                                    Expanded(child: _ticketStatTileSimple('Sales Revenue', '₱${ticketRevenue.toStringAsFixed(2)}')),
                                  ]);
                                } else {
                                  return Wrap(spacing: 8, runSpacing: 8, children: [
                                    SizedBox(width: (constraints.maxWidth - 8) / 2, child: _ticketStatTileSimple('Total Tickets', tickets.fold<int>(0, (s, e) => s + e.totalTickets).toString())),
                                    SizedBox(width: (constraints.maxWidth - 8) / 2, child: _ticketStatTileSimple('Tickets Sold', tickets.fold<int>(0, (s, e) => s + e.sales.fold<int>(0, (si, sale) => si + sale.qty)).toString())),
                                    SizedBox(width: (constraints.maxWidth - 8) / 2, child: _ticketStatTileSimple('Tickets Remaining', (tickets.fold<int>(0, (s, e) => s + e.totalTickets) - tickets.fold<int>(0, (s, e) => s + e.sales.fold<int>(0, (si, sale) => si + sale.qty))).toString())),
                                    SizedBox(width: (constraints.maxWidth - 8) / 2, child: _ticketStatTileSimple('Sales Revenue', '₱${ticketRevenue.toStringAsFixed(2)}')),
                                  ]);
                                }
                              })),
                          const SizedBox(height: 12),

                          // ticket events list (compact)
                          ..._buildTicketEventsList(ticketsLimit, _showMoreTickets),

                          if (tickets.length > ticketsLimit)
                            _showMorePill(
                              expanded: _showMoreTickets,
                              onTap: () => setState(() => _showMoreTickets = !_showMoreTickets),
                            ),

                          const SizedBox(height: 12),
                          _panelTitle('Recent Sales'),
                          Container(decoration: _panelDecoration(), padding: const EdgeInsets.all(12), child: Column(children: [
                            ..._buildRecentSalesList(recentSalesLimit, _showMoreTickets),
                          ])),
                        ]),
                      ),
                    ],
                  );

                  final charts = Column(children: [
                    Container(width: double.infinity, decoration: _panelDecoration(), padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Expense Breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      SizedBox(height: 200, child: PieChart(PieChartData(sections: pieSections, sectionsSpace: 4, borderData: FlBorderData(show: false)))),
                      const SizedBox(height: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: spentByCategory().entries.map((e) {
                        return Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Row(children: [
                          Container(width: 12, height: 12, decoration: BoxDecoration(color: _randomColorForKey(e.key), borderRadius: BorderRadius.circular(6))),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${e.key} — ₱${e.value.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey))),
                        ]));
                      }).toList())
                    ])),
                    const SizedBox(height: 12),
                    Container(width: double.infinity, decoration: _panelDecoration(), padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Income vs Expense (Monthly)', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      SizedBox(height: 200, child: BarChart(_buildBarData(), swapAnimationDuration: const Duration(milliseconds: 350))),
                    ]))
                  ]);

                  if (isWide) {
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 14), SizedBox(width: 360, child: charts)]);
                  } else {
                    return Column(children: [left, const SizedBox(height: 14), charts]);
                  }
                }),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTransactionDialog,
        child: const Icon(Icons.add),
        backgroundColor: emeraldEnd,
        foregroundColor: Colors.white,
      ),
    );
  }

  // helper builders that respect compact limits and "show more" flags
  List<Widget> _buildOverviewCategories(int limit, bool expanded) {
    final list = expanded ? categories : categories.take(limit).toList();
    return list.map((c) {
      final spent = spentByCategory()[c.name] ?? 0.0;
      final ratio = c.budget > 0 ? (spent / c.budget).clamp(0.0, 1.0) : 0.0;
      return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: _categoryRow(c.name, spent, c.budget, ratio, c));
    }).toList();
  }

  List<Widget> _buildOverviewTransactions(int limit, bool expanded) {
    final list = expanded ? transactions : transactions.take(limit).toList();
    return [
      Container(decoration: _panelDecoration(), padding: const EdgeInsets.all(12), child: Column(children: list.take(6).map((t) => _transactionRow(t)).toList()))
    ];
  }

  List<Widget> _buildCategoryList(int limit, bool expanded) {
    final list = expanded ? categories : categories.take(limit).toList();
    return list.map((c) {
      final spent = spentByCategory()[c.name] ?? 0.0;
      final ratio = c.budget > 0 ? (spent / c.budget).clamp(0.0, 1.0) : 0.0;
      return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: _categoryRow(c.name, spent, c.budget, ratio, c));
    }).toList();
  }

  List<Widget> _buildTransactionsList(int limit, bool expanded) {
    final list = expanded ? transactions : transactions.take(limit).toList();
    return list.map((t) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.description, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${t.category} • ${t.date.toIso8601String().substring(0, 10)}', style: const TextStyle(color: Colors.grey)),
          ]),
          Row(children: [
            Text((t.type == 'expense' ? '- ' : '') + '₱${t.amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: t.type == 'expense' ? Colors.red : Colors.green)),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => setState(() => transactions.removeWhere((x) => x.id == t.id)),
              child: const Text('Delete'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
            )
          ])
        ]),
      );
    }).toList();
  }

  List<Widget> _buildTicketEventsList(int limit, bool expanded) {
    final list = expanded ? tickets : tickets.take(limit).toList();
    return list.map((ev) {
      final sold = ev.sales.fold<int>(0, (a, b) => a + b.qty);
      final remaining = (ev.totalTickets - sold).clamp(0, ev.totalTickets);
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: _panelDecoration(),
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(ev.event, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text('${ev.totalTickets} tickets • ₱${ev.price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey))])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$sold sold • $remaining left', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _gradientButton(onPressed: () => _openAddEventDialog(ev), child: const Text('Edit')),
              _gradientButton(onPressed: () => _openRecordSaleDialog(ev), child: const Text('Record Sale')),
              OutlinedButton(onPressed: () => setState(() => tickets.removeWhere((x) => x.id == ev.id)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), foregroundColor: Colors.red), child: const Text('Delete'))
            ])
          ])
        ]),
      );
    }).toList();
  }

  List<Widget> _buildRecentSalesList(int limit, bool expanded) {
    final allSales = tickets.expand((ev) => ev.sales.map((s) {
      return {'sale': s, 'event': ev};
    })).toList();
    final list = expanded ? allSales : allSales.take(limit).toList();
    return list.map((entry) {
      final TicketSale s = entry['sale'] as TicketSale;
      final TicketEvent ev = entry['event'] as TicketEvent;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(children: [
          Expanded(flex: 2, child: Text(s.buyer, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 3, child: Text(ev.event, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 1, child: Text('${s.qty}', textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('₱${(s.qty * ev.price).toStringAsFixed(2)}', textAlign: TextAlign.right)),
          const SizedBox(width: 12),
          SizedBox(width: 110, child: Text(s.date.toIso8601String().substring(0, 10), textAlign: TextAlign.right)),
        ]),
      );
    }).toList();
  }
}
