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

class FuelAdminFinal extends StatefulWidget {
  const FuelAdminFinal({super.key});

  @override
  State<FuelAdminFinal> createState() => _FuelAdminFinalState();
}

class _FuelAdminFinalState extends State<FuelAdminFinal>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  final DateTime _now = DateTime.now();

  double todaysSales = 0.0;
  double todaysExpense = 0.0;
  double todaysDelivery = 0.0;

  final Map<String, Map<String, de.DayEntryStatus>> weeklyStatus = {};

  bool _loading = true;

  // ✅ Needed for horizontal scroll when screen is compressed
  final ScrollController _mainHScroll = ScrollController();
  final ScrollController _summaryHScroll = ScrollController();

  // ✅ format with commas
  final NumberFormat _moneyFmt = NumberFormat.decimalPattern();

  String _money(num v) => _moneyFmt.format(v.round());

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 5, vsync: this);

    // listen to tank updates (for tank widget)
    Services.tank.addListener(_onTankChanged);

    Future.microtask(() async {
      await Services.init();

      // Load today's totals
      final salesTotal = await Services.saleRepo.getTodayTotalAmount();
      final expenseTotal = Services.expense.todayTotal;

      await _loadWeeklyFromDayEntryCache();

      if (!mounted) return;
      setState(() {
        todaysSales = salesTotal;
        todaysExpense = expenseTotal;
        _loading = false;
      });
    });
  }

  void _onTankChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    Services.tank.removeListener(_onTankChanged);
    tabController.dispose();
    _mainHScroll.dispose();
    _summaryHScroll.dispose();
    super.dispose();
  }

  // =====================
  // DATE HELPERS
  // =====================

  String _businessDateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _uiDayKey(DateTime d) => DateFormat('EEE dd').format(d);

  DateTime _weekStart(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

  // =====================
  // WEEKLY STATUS (DB → UI)
  // =====================

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

  // =====================
  // MARK TAB AS DRAFT
  // =====================

  Future<void> _markDraft(String type) async {
    final date = _businessDateKey(_now);
    await Services.dayEntry.markDraft(date, type);
    await _loadWeeklyFromDayEntryCache();
    if (mounted) setState(() {});
  }

  // =====================
  // SEND DATA CONFIRMATION
  // =====================

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
        title: const Text('Send Today’s Data?', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row('Sales', statuses['Sale'] ?? de.DayEntryStatus.none),
            _row('Delivery', statuses['Del'] ?? de.DayEntryStatus.none),
            _row('Expense', statuses['Exp'] ?? de.DayEntryStatus.none),
            _row('Settlement', statuses['Set'] ?? de.DayEntryStatus.none),
            const SizedBox(height: 12),
            Text('Business Date: $todayUiKey', style: const TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white))),
          Icon(icon, color: color, size: 16),
        ],
      ),
    );
  }

  Future<void> _sendData() async {
    final date = _businessDateKey(_now);

    await Services.dayEntry.submitDay(
      businessDate: date,
      submittedAt: DateTime.now(),
    );

    await _loadWeeklyFromDayEntryCache();

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data successfully sent'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _addSale(double v) => setState(() => todaysSales += v);
  void _addExpense(double v) => setState(() => todaysExpense += v);
  void _addDelivery(double v) => setState(() => todaysDelivery += v);

  bool get isTodaySubmitted {
    final todayUiKey = _uiDayKey(_now);
    final m = weeklyStatus[todayUiKey];
    if (m == null) return false;
    return m.values.every((s) => s == de.DayEntryStatus.submitted);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0b1220),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // SIDEBAR
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

          // MAIN
          Expanded(
            child: Column(
              children: [
                _buildTopBarResponsive(),
                _buildSummaryCardsResponsive(),
                Expanded(child: _buildMainBodyResponsive()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================
  // TOP BAR (Responsive)
  // =====================

  Widget _buildTopBarResponsive() {
    return LayoutBuilder(
      builder: (context, c) {
        final isTight = c.maxWidth < 900;

        final title = const Text(
          'SmartBusiness ERP',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
        );

        final welcome = const Text('Welcome admin', style: TextStyle(color: Colors.white70));

        final date = Text(
          DateFormat('EEEE, MMM d, yyyy').format(_now),
          style: const TextStyle(color: Colors.white60),
        );

        final sendBtn = ElevatedButton.icon(
          onPressed: isTodaySubmitted ? null : _confirmSendData,
          icon: const Icon(Icons.send, size: 18),
          label: const Text('Send Data'),
        );

        if (!isTight) {
          return Container(
            color: const Color(0xFF0f172a),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              children: [
                title,
                const SizedBox(width: 20),
                welcome,
                const Spacer(),
                date,
                const SizedBox(width: 20),
                sendBtn,
              ],
            ),
          );
        }

        // tight width -> stack into 2 rows (no overflow)
        return Container(
          color: const Color(0xFF0f172a),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: title)),
                  const SizedBox(width: 12),
                  welcome,
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: date),
                  sendBtn,
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // =====================
  // SUMMARY CARDS (Responsive)
  // =====================

  Widget _buildSummaryCardsResponsive() {
    const minWidth = 900.0;

    return Container(
      color: const Color(0xFF111827),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: LayoutBuilder(
        builder: (context, c) {
          final isWide = c.maxWidth >= minWidth;

          final cardsRow = Row(
            children: [
              Expanded(child: _summaryCard('Today\'s Sales', todaysSales, Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard('Today\'s Expense', todaysExpense, Colors.red)),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard('Today\'s Delivery', todaysDelivery, Colors.orange)),
            ],
          );

          if (isWide) return cardsRow;

          return Scrollbar(
            controller: _summaryHScroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _summaryHScroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: minWidth, child: cardsRow),
            ),
          );
        },
      ),
    );
  }

  // =====================
  // MAIN BODY (Responsive)
  // =====================

  Widget _buildMainBodyResponsive() {
    const minBodyWidth = 1280.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= minBodyWidth;

        if (isWide) return _buildMainBodyRow();

        return Scrollbar(
          controller: _mainHScroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _mainHScroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: minBodyWidth,
              child: _buildMainBodyRow(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainBodyRow() {
    return Row(
      children: [
        // LEFT: ENTRY TABS
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
                        _markDraft('Sale');
                      },
                      onDraftMarked: () => _markDraft('Sale'),
                    ),
                    DeliveryTab(
                      onSubmitted: () => _markDraft('Del'),
                      onDeliveryRecorded: (amount) {
                        setState(() => todaysDelivery = amount);
                      },
                    ),
                    ExpenseTab(onSubmitted: () => _markDraft('Exp')),
                    SettlementTab(onSubmitted: () => _markDraft('Set')),
                    const ExternalPaymentsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // MIDDLE: WEEKLY SUMMARY
        Expanded(
          flex: 1,
          child: WeeklySummaryPerfect(weeklyStatus: weeklyStatus),
        ),

        const SizedBox(width: 16),

        // RIGHT: TANK LEVELS
        const Expanded(
          flex: 2,
          child: TankLevelsPerfect(),
        ),
      ],
    );
  }

  // =====================
  // SUMMARY CARD
  // =====================

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
            '₦${_money(value)}', // ✅ comma formatted
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _sideIcon(IconData icon, [bool active = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Icon(icon, size: 28, color: active ? Colors.green : Colors.grey),
    );
  }
}
