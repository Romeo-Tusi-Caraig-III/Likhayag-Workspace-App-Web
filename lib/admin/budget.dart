// lib/admin/budget_dashboard.dart - Combined & cleaned version
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

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
  List<Category> categories = [];
  List<TransactionModel> transactions = [];
  List<TicketEvent> tickets = [];

  late TabController _tabController;
  final Map<String, TextEditingController> _budgetControllers = {};

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
    for (var ctl in _budgetControllers.values) {
      ctl.dispose();
    }
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

        for (var c in categories) {
          _budgetControllers[c.id] = TextEditingController(text: c.budget.toStringAsFixed(0));
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading budget: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction recorded')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Widget _gradientButton({required Widget child, required VoidCallback onPressed, EdgeInsets? padding, BorderRadius? borderRadius}) {
    final br = borderRadius ?? BorderRadius.circular(999);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [emeraldStart, emeraldEnd]),
          borderRadius: br,
          boxShadow: [BoxShadow(color: emeraldEnd.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: br,
          child: Container(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: DefaultTextStyle(style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), child: child),
          ),
        ),
      ),
    );
  }

  Widget _gradientButtonIcon({required IconData icon, required String label, required VoidCallback onPressed, EdgeInsets? padding}) {
    return _gradientButton(
      onPressed: onPressed,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  ButtonStyle _textButtonStyle() {
    return TextButton.styleFrom(foregroundColor: emeraldEnd);
  }

  Widget _gradientPillFab({required VoidCallback onPressed, required IconData icon, required String label, double height = 44}) {
    final BorderRadius br = BorderRadius.circular(28);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [emeraldStart, emeraldEnd]),
          borderRadius: br,
          boxShadow: [BoxShadow(color: emeraldEnd.withOpacity(0.20), blurRadius: 10, offset: const Offset(0, 6))],
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: br,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 10),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAddTransactionDialog() {
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, -6))],
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: StatefulBuilder(builder: (contextSB, setStateSB) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Add Transaction',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Material(
                            color: emeraldStart,
                            shape: const CircleBorder(),
                            elevation: 4,
                            child: IconButton(
                              splashRadius: 20,
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.pop(sheetContext),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtl,
                        decoration: InputDecoration(
                          hintText: 'Description',
                          filled: true,
                          fillColor: const Color(0xFFF6F7FB),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: type,
                        isExpanded: true,
                        items: ['expense', 'income']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e[0].toUpperCase() + e.substring(1))))
                            .toList(),
                        onChanged: (v) => setStateSB(() => type = v ?? 'expense'),
                        decoration: InputDecoration(
                          hintText: 'Type',
                          filled: true,
                          fillColor: const Color(0xFFF6F7FB),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: category,
                        isExpanded: true,
                        items: categories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                        onChanged: (v) => setStateSB(() => category = v ?? (categories.isNotEmpty ? categories.first.name : 'General')),
                        decoration: InputDecoration(
                          hintText: 'Category',
                          filled: true,
                          fillColor: const Color(0xFFF6F7FB),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountCtl,
                        decoration: InputDecoration(
                          hintText: 'Amount',
                          filled: true,
                          fillColor: const Color(0xFFF6F7FB),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Date: '),
                          TextButton(
                            style: _textButtonStyle(),
                            onPressed: () async {
                              final picked = await showDatePicker(context: contextSB, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                              if (picked != null) setStateSB(() => date = picked);
                            },
                            child: Text(date.toIso8601String().substring(0, 10)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('(Receipt upload not implemented in this demo)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            style: _textButtonStyle(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          _gradientButton(
                            onPressed: () {
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
                                    date: date,
                                  ),
                                );
                              });
                              Navigator.pop(sheetContext);
                            },
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            borderRadius: BorderRadius.circular(12),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                child: _gradientButton(
                  onPressed: () {
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
                  },
                  child: const Text('Save'),
                ),
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
                Row(
                  children: [
                    const Text('Date: '),
                    TextButton(
                      style: _textButtonStyle(),
                      onPressed: () async {
                        final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (picked != null) setState(() => date = picked);
                      },
                      child: Text(date.toIso8601String().substring(0, 10)),
                    )
                  ],
                )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), style: _textButtonStyle(), child: const Text('Cancel')),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _gradientButton(
                  onPressed: () {
                    final qty = int.tryParse(qtyCtl.text) ?? 1;
                    setState(() {
                      ev.sales.add(TicketSale(buyer: buyerCtl.text.isEmpty ? 'Buyer' : buyerCtl.text, qty: qty, date: date));
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
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
      if (idx >= 0) {
        target[idx] += amount;
      }
    }

    for (var t in transactions) {
      final key = t.date.toIso8601String().substring(0, 7);
      if (t.type == 'income') {
        addMonthValue(key, t.amount, income);
      }
      if (t.type == 'expense') {
        addMonthValue(key, t.amount, expense);
      }
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
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
              final label = months[idx].substring(5);
              return SideTitleWidget(
              meta: meta,
              child: Text(label, style: const TextStyle(fontSize: 10)),
            );
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

  Widget _statPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
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
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
              ),
            ),
            _gradientButton(
              onPressed: () {
                setState(() {
                  c.budget = double.tryParse(ctl.text) ?? c.budget;
                });
              },
              child: const Text('Update'),
            ),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  categories.removeWhere((x) => x.id == c.id);
                  _budgetControllers.remove(c.id)?.dispose();
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              child: const Text('Delete'),
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Set monthly budget', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 12),
                controls,
                const SizedBox(height: 10),
                Text('${(ratio * 100).toStringAsFixed(1)}% of budget used', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: ratio, minHeight: 10, backgroundColor: Colors.grey[200], color: emeraldEnd),
              ],
            ),
          ),
        );
      }

      // Wide layout
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('Set monthly budget', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const SizedBox(height: 10),
                    Text('${(ratio * 100).toStringAsFixed(1)}% of budget used', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: ratio, minHeight: 10, backgroundColor: Colors.grey[200], color: emeraldEnd),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              controls,
            ],
          ),
        ),
      );
    });
  }

  void _openAddCategoryDialog() {
    final nameCtl = TextEditingController();
    final budgetCtl = TextEditingController(text: '1000');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: 'Category Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: budgetCtl,
                decoration: const InputDecoration(labelText: 'Monthly Budget (₱)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: _textButtonStyle(),
              child: const Text('Cancel'),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _gradientButton(
                onPressed: () {
                  final name = nameCtl.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Category name is required')),
                    );
                    return;
                  }

                  final budget = double.tryParse(budgetCtl.text) ?? 0.0;
                  setState(() {
                    categories.add(Category(
                      id: UniqueKey().toString(),
                      name: name,
                      budget: budget,
                    ));
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Add'),
              ),
            ),
          ],
        );
      },
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
        title: const Text('Budget Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildCategoriesTab(),
          _buildTransactionsTab(),
          _buildTicketsTab(),
        ],
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
          // Stats Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              _statPill('Total Funds', '₱${totalFunds.toStringAsFixed(2)}'),
              _statPill('Total Expenses', '₱${totalExpenses.toStringAsFixed(2)}'),
              _statPill('Balance', '₱${balance.toStringAsFixed(2)}'),
              _statPill('Ticket Revenue', '₱${ticketRevenue.toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 20),

          // Charts Section
          Container(
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
                  spacing: 12,
                  runSpacing: 8,
                  children: spent.entries.map((e) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _randomColorForKey(e.key),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(e.key, style: const TextStyle(fontSize: 12)),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Monthly Trends
          Container(
            decoration: _panelDecoration(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _panelTitle('6-Month Trend'),
                SizedBox(
                  height: 220,
                  child: BarChart(_buildBarData()),
                ),
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
          const SizedBox(height: 20),

          // Top Spending Categories
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
                            Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('₱${entry.value.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: Colors.grey[200],
                          color: ratio > 1.0 ? Colors.red : emeraldEnd,
                        ),
                      ],
                    ),
                  );
                }),
                if (topCategories.length > 3)
                  TextButton(
                    onPressed: () => setState(() => _showMoreOverview = !_showMoreOverview),
                    style: _textButtonStyle(),
                    child: Text(_showMoreOverview ? 'Show Less' : 'Show More'),
                  ),
              ],
            ),
          ),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Budget Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _gradientButtonIcon(
                icon: Icons.add,
                label: 'Add Category',
                onPressed: _openAddCategoryDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...displayCategories.map((c) {
            final used = spent[c.name] ?? 0.0;
            final ratio = c.budget > 0 ? used / c.budget : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _categoryRow(c.name, used, c.budget, ratio, c),
            );
          }),
          if (categories.length > 5)
            TextButton(
              onPressed: () => setState(() => _showMoreCategories = !_showMoreCategories),
              style: _textButtonStyle(),
              child: Text(_showMoreCategories ? 'Show Less' : 'Show More'),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _gradientButtonIcon(
                icon: Icons.add,
                label: 'Add',
                onPressed: _openAddTransactionDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: transactions.isEmpty
              ? const Center(child: Text('No transactions yet', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: displayTransactions.length + (transactions.length > 10 ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == displayTransactions.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: TextButton(
                            onPressed: () => setState(() => _showMoreTransactions = !_showMoreTransactions),
                            style: _textButtonStyle(),
                            child: Text(_showMoreTransactions ? 'Show Less' : 'Show More'),
                          ),
                        ),
                      );
                    }

                    final tx = displayTransactions[index];
                    final isIncome = tx.type == 'income';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isIncome ? emeraldEnd : Colors.redAccent,
                          child: Icon(
                            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(tx.description, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${tx.category} • ${tx.date.toIso8601String().substring(0, 10)}'),
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
    );
  }

  Widget _buildTicketsTab() {
    final displayTickets = _showMoreTickets ? tickets : tickets.take(5).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ticket Events', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _gradientButtonIcon(
                icon: Icons.add,
                label: 'Add Event',
                onPressed: () => _openAddEventDialog(),
              ),
            ],
          ),
        ),
        Expanded(
          child: tickets.isEmpty
              ? const Center(child: Text('No ticket events yet', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: displayTickets.length + (tickets.length > 5 ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == displayTickets.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: TextButton(
                            onPressed: () => setState(() => _showMoreTickets = !_showMoreTickets),
                            style: _textButtonStyle(),
                            child: Text(_showMoreTickets ? 'Show Less' : 'Show More'),
                          ),
                        ),
                      );
                    }

                    final ev = displayTickets[index];
                    final sold = ev.sales.fold<int>(0, (s, sale) => s + sale.qty);
                    final revenue = sold * ev.price;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
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
                                PopupMenuButton(
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      child: const Text('Edit'),
                                      onTap: () => Future.delayed(Duration.zero, () => _openAddEventDialog(ev)),
                                    ),
                                    PopupMenuItem(
                                      child: const Text('Record Sale'),
                                      onTap: () => Future.delayed(Duration.zero, () => _openRecordSaleDialog(ev)),
                                    ),
                                    PopupMenuItem(
                                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                      onTap: () {
                                        setState(() {
                                          tickets.removeWhere((t) => t.id == ev.id);
                                        });
                                      },
                                    ),
                                  ],
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
                                      Text('Price: ₱${ev.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                                      const SizedBox(height: 4),
                                      Text('Sold: $sold / ${ev.totalTickets}', style: const TextStyle(fontSize: 13)),
                                      const SizedBox(height: 4),
                                      Text('Revenue: ₱${revenue.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: emeraldEnd)),
                                    ],
                                  ),
                                ),
                                CircularProgressIndicator(
                                  value: ev.totalTickets > 0 ? sold / ev.totalTickets : 0.0,
                                  backgroundColor: Colors.grey[200],
                                  color: emeraldEnd,
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
