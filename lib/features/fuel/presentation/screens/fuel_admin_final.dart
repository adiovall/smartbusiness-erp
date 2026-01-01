// lib/features/fuel/presentation/screens/fuel_admin_final.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/entry_tabs/sale_tab.dart';
import '../widgets/entry_tabs/delivery_tab.dart';
import '../widgets/entry_tabs/expense_tab.dart';
import '../widgets/entry_tabs/settlement_tab.dart';
import '../widgets/entry_tabs/external_payments_tab.dart';
import '../widgets/tank_levels_perfect.dart';
import '../widgets/weekly_summary_perfect.dart';

import '../../../../core/services/service_registry.dart';
import '../../../../core/models/day_entry.dart' as de;

/// =====================
/// MAIN SCREEN WIDGET
/// =====================
class FuelAdminFinal extends StatefulWidget {
  const FuelAdminFinal({super.key});

  @override
  State<FuelAdminFinal> createState() => _FuelAdminFinalState();
}

class _FuelAdminFinalState extends State<FuelAdminFinal>
    with SingleTickerProviderStateMixin {
  /// =====================
  /// STATE & CONTROLLERS
  /// =====================
  late TabController tabController;

  final DateTime _now = DateTime.now();

  double todaysSales = 0.0;
  double todaysExpense = 0.0;
  double todaysDelivery = 0.0;

  /// Weekly status map used by WeeklySummaryPerfect
  /// Key format: "Mon 15"
  /// Value: {Sale: DayEntryStatus.draft, Del: ..., Exp: ..., Set: ...}
  final Map<String, Map<String, de.DayEntryStatus>> weeklyStatus = {};

  /// For showing UI only (loading DB on open)
  bool _loading = true;

  /// =====================
  /// INIT
  /// =====================
  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 5, vsync: this);

    Services.tank.addListener(_onTankChanged);

    Future.microtask(() async {
      await Services.init();

      // === ADD THESE LINES ===
      final salesTotal = await Services.saleRepo.getTodayTotalAmount();
      setState(() => todaysSales = salesTotal);
      final expenseTotal = Services.expense.todayTotal;

      if (mounted) {
        setState(() {
          todaysSales = salesTotal;
          todaysExpense = expenseTotal;
        });
      }
      // === END ADD ===

      await _loadWeeklyFromDayEntryCache();

      if (mounted) setState(() => _loading = false);
    });
  }

    void _onTankChanged() {
      if (mounted) setState(() {}); // Rebuild screen when tank changes
    }

    @override
    void dispose() {
      Services.tank.removeListener(_onTankChanged); // ← Clean up
      tabController.dispose();
      super.dispose();
    }

  /// =====================
  /// DATE HELPERS
  /// =====================

  /// Business date key for DB (yyyy-MM-dd)
  String _businessDateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// UI key for weekly widget (EEE dd) e.g. Mon 15
  String _uiDayKey(DateTime d) => DateFormat('EEE dd').format(d);

  DateTime _weekStart(DateTime d) =>
      d.subtract(Duration(days: d.weekday - 1)); // Monday start

  /// =====================
  /// WEEKLY STATUS (DB → UI)
  /// =====================

  Future<void> _loadWeeklyFromDayEntryCache() async {
    final start = _weekStart(_now);

    weeklyStatus.clear();

    for (int i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      final uiKey = _uiDayKey(day);
      final dbKey = _businessDateKey(day);

      final entry = Services.dayEntry.getFromCache(dbKey);

      weeklyStatus[uiKey] = {
        'Sale': entry?.sale ?? de.DayEntryStatus.none,
        'Del': entry?.delivery ?? de.DayEntryStatus.none,
        'Exp': entry?.expense ?? de.DayEntryStatus.none,
        'Set': entry?.settlement ?? de.DayEntryStatus.none,
      };
    }
  }

  /// =====================
  /// MARK TAB AS DRAFT (YELLOW)
  /// =====================
  Future<void> _markDraft(String type) async {
    final date = _businessDateKey(_now);

    await Services.dayEntry.markDraft(date, type);

    await _loadWeeklyFromDayEntryCache();

    if (mounted) setState(() {});
  }

  /// =====================
  /// SEND DATA CONFIRMATION
  /// (editable submission date will be added later)
  /// =====================
  Future<void> _confirmSendData() async {
    final todayUiKey = _uiDayKey(_now);
    final statuses = weeklyStatus[todayUiKey];

    if (statuses == null) return;

    final hasDraft = statuses.values.any((s) => s == de.DayEntryStatus.draft);

    if (!hasDraft) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to send today')),
      );
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF020617),
        title: const Text(
          'Send Today’s Data?',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row('Sales', statuses['Sale'] ?? de.DayEntryStatus.none),
            _row('Delivery', statuses['Del'] ?? de.DayEntryStatus.none),
            _row('Expense', statuses['Exp'] ?? de.DayEntryStatus.none),
            _row('Settlement', statuses['Set'] ?? de.DayEntryStatus.none),
            const SizedBox(height: 12),
            Text(
              'Business Date: $todayUiKey',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Send'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (proceed == true) {
      await _sendData();
    }
  }

  Widget _row(String label, de.DayEntryStatus status) {
    final color = status == de.DayEntryStatus.draft
        ? Colors.amber
        : status == de.DayEntryStatus.submitted
            ? Colors.green
            : Colors.grey;

    final icon = status == de.DayEntryStatus.none
        ? Icons.circle_outlined
        : Icons.check_circle;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white)),
          ),
          Icon(icon, color: color, size: 16),
        ],
      ),
    );
  }



  /// =====================
  /// FINAL SEND ACTION (GREEN)
  /// =====================
  Future<void> _sendData() async {
    final date = _businessDateKey(_now);

    // Submit (turns all draft → submitted, keeps none as none)
    await Services.dayEntry.submitDay(
  businessDate: date,
  submittedAt: DateTime.now(),
);
    await _loadWeeklyFromDayEntryCache();

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data successfully sent'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// =====================
  /// HELPERS
  /// =====================
  void _addSale(double v) => setState(() => todaysSales += v);
  void _addExpense(double v) => setState(() => todaysExpense += v);
  void _addDelivery(double v) => setState(() => todaysDelivery += v);

  bool get isTodaySubmitted {
    final todayUiKey = _uiDayKey(_now);
    final m = weeklyStatus[todayUiKey];
    if (m == null) return false;

    // "submitted" means every section is green.
    // If you want "submitted only for entries that exist", we can adjust later.
    return m.values.every((s) => s == de.DayEntryStatus.submitted);
  }

  /// =====================
  /// BUILD UI
  /// =====================
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0b1220),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          /// =====================
          /// SIDEBAR
          /// =====================
          Container(
            width: 70,
            color: const Color(0xFF020617),
            child: Column(
              children: [
                const SizedBox(height: 24),
                _sideIcon(Icons.local_gas_station, true),
                _sideIcon(Icons.store_mall_directory),
                _sideIcon(Icons.water_drop),
                _sideIcon(Icons.analytics),
                const Spacer(),
                _sideIcon(Icons.settings),
                const SizedBox(height: 24),
              ],
            ),
          ),

          /// =====================
          /// MAIN CONTENT
          /// =====================
          Expanded(
            child: Column(
              children: [
                /// TOP BAR
                _buildTopBar(),

                /// SUMMARY CARDS
                _buildSummaryCards(),

                /// MAIN BODY
                Expanded(child: _buildMainBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// =====================
  /// TOP BAR
  /// =====================
  Widget _buildTopBar() {
    return Container(
      color: const Color(0xFF0f172a),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          const Text(
            'SmartBusiness ERP',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          const Text(
            'Welcome admin',
            style: TextStyle(color: Colors.white70),
          ),
          const Spacer(),
          Text(
            DateFormat('EEEE, MMM d, yyyy').format(_now),
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(width: 20),
          ElevatedButton.icon(
            onPressed: isTodaySubmitted ? null : _confirmSendData,
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Send Data'),
          ),
        ],
      ),
    );
  }

  /// =====================
  /// SUMMARY CARDS
  /// =====================
  Widget _buildSummaryCards() {
    return Container(
      color: const Color(0xFF111827),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: _summaryCard(
              'Today\'s Sales',
              todaysSales,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _summaryCard(
              'Today\'s Expense',
              todaysExpense,
              Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _summaryCard(
              'Today\'s Delivery',
              todaysDelivery,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  /// =====================
  /// MAIN BODY
  /// =====================
  Widget _buildMainBody() {
    return Row(
      children: [
        /// LEFT: ENTRY TABS
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Container(
                height: 50,
                color: const Color(0xFF1e293b),
                child: TabBar(
                  controller: tabController,
                  labelColor: Colors.green,
                  tabs: const [
                    Tab(text: 'Sale'),
                    Tab(text: 'Delivery'),
                    Tab(text: 'Expense'),
                    Tab(text: 'Settlement'),
                    Tab(text: 'External'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: tabController,
                  children: [
                    SaleTab(
                      onSaleRecorded: (total) {
                        _addSale(total);
                        _markDraft('Sale'); // Optional: mark draft on submit too
                      },
                      onDraftMarked: () => _markDraft('Sale'),
                    ),

                    DeliveryTab(
                      onSubmitted: () => _markDraft('Del'),
                      onDeliveryRecorded: (amount) {
                        setState(() => todaysDelivery = amount);
                      },
                    ),
                    ExpenseTab(
                      onSubmitted: () => _markDraft('Exp'),
                    ),
                    SettlementTab(
                      onSubmitted: () => _markDraft('Set'),
                    ),
                    const ExternalPaymentsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        /// MIDDLE: WEEKLY SUMMARY
        Expanded(
          flex: 1,
          child: WeeklySummaryPerfect(weeklyStatus: weeklyStatus),
        ),

        const SizedBox(width: 16),

        /// RIGHT: TANK LEVELS
        Expanded(
          flex: 2,
          child: TankLevelsPerfect(),
        ),
      ],
    );
  }

  /// =====================
  /// SUMMARY CARD
  /// =====================
  Widget _summaryCard(String title, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            '₦${value.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// =====================
  /// SIDEBAR ICON
  /// =====================
  Widget _sideIcon(IconData icon, [bool active = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Icon(
        icon,
        size: 28,
        color: active ? Colors.green : Colors.grey,
      ),
    );
  }
}
