// lib/features/fuel/presentation/widgets/analytics/insight_view.dart
//
// The "Insight" tab of the Analytics screen: Today/Week/Month/Year
// period selector, KPI cards (Revenue/Expenses/Net Profit/Outstanding
// Debt), and the Sales-by-Pump bar chart. More sections (Tank Levels,
// Fuel Performance, Suppliers, Expense Breakdown, Delivery History,
// Debt Overview, External Payments, Cash Flow) will be added here in
// later stages.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../../core/services/analytics_service.dart';
import '../../../../../core/services/service_registry.dart';
import 'shared.dart';

class AnalyticsInsightView extends StatefulWidget {
  const AnalyticsInsightView({super.key});

  @override
  State<AnalyticsInsightView> createState() => _AnalyticsInsightViewState();
}

class _AnalyticsInsightViewState extends State<AnalyticsInsightView> {
  String _insightPeriod = 'Today';
  DateTime? _customFrom;
  DateTime? _customTo;

  bool _loadingPumpPerformance = true;
  List<PumpPerformance> _pumpPerformance = [];
  bool _loadingFuelPerformance = true;
  List<FuelPerformance> _fuelPerformance = [];
  bool _loadingInsightTrend = true;
  List<DayAnalytics> _insightTrend = [];
  bool _loadingTopSuppliers = true;
  List<SupplierPerformance> _topSuppliers = [];
  bool _loadingExternalPayments = true;
  List<ExternalPaymentSummary> _externalPayments = [];
  List<AiInsight> _aiInsights = [];
  bool _loadingAiInsights = true;

  bool _loadingCashFlow = true;
  CashFlowSummary? _cashFlow;

  bool _loadingExpenseBreakdown = true;
  List<ExpenseCategoryTotal> _expenseBreakdown = [];

  bool _loadingDebtOverview = true;
  List<DebtSummary> _debtOverview = [];

  List<TankLevelSnapshot> _tankLevels = [];
  bool _loadingTankLevels = true;

  @override
  void initState() {
    super.initState();
    _loadPumpPerformance();
    _loadInsightTrend();
    _loadFuelPerformance();
    _loadTopSuppliers();
    _loadExpenseBreakdown();
    _loadDebtOverview();
    _loadExternalPayments();
    _loadCashFlow();
    _loadAiInsights();
    _loadTankLevels();
  }


 void _reloadAll() {
    _loadPumpPerformance();
    _loadInsightTrend();
    _loadFuelPerformance();
    _loadTopSuppliers();
    _loadExpenseBreakdown();
    _loadDebtOverview();
    _loadExternalPayments();
    _loadCashFlow();
    _loadAiInsights();
    _loadTankLevels();
  }

  Map<String, String?> _computeInsightDateRange() {
    final now = DateTime.now();
    String fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

    switch (_insightPeriod) {
      case 'Today':
        return {'from': fmt(now), 'to': fmt(now)};
      case 'Week':
        final start = now.subtract(Duration(days: now.weekday - 1));
        return {'from': fmt(start), 'to': fmt(now)};
      case 'Month':
        final start = DateTime(now.year, now.month, 1);
        return {'from': fmt(start), 'to': fmt(now)};
      case 'Year':
        final start = DateTime(now.year, 1, 1);
        return {'from': fmt(start), 'to': fmt(now)};
      case 'Custom':
        if (_customFrom == null || _customTo == null) return {'from': null, 'to': null};
        return {'from': fmt(_customFrom!), 'to': fmt(_customTo!)};
      default:
        return {'from': null, 'to': null};
    }
  }

  Future<void> _loadTankLevels() async {
  setState(() => _loadingTankLevels = true);
    final data = await Services.analytics.fetchLatestTankLevels();
    if (!mounted) return;
    setState(() {
      _tankLevels = data;
      _loadingTankLevels = false;
    });
  }

  Future<void> _loadAiInsights() async {
    setState(() => _loadingAiInsights = true);

    final range = _computeInsightDateRange();

    // Compute previous period range for comparison
    final now = DateTime.now();
    String fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
    String? prevFrom, prevTo;

    switch (_insightPeriod) {
      case 'Today':
        final yesterday = now.subtract(const Duration(days: 1));
        prevFrom = prevTo = fmt(yesterday);
        break;
      case 'Week':
        final thisStart = now.subtract(Duration(days: now.weekday - 1));
        prevTo = fmt(thisStart.subtract(const Duration(days: 1)));
        prevFrom = fmt(thisStart.subtract(const Duration(days: 7)));
        break;
      case 'Month':
        final thisStart = DateTime(now.year, now.month, 1);
        prevTo = fmt(thisStart.subtract(const Duration(days: 1)));
        prevFrom = fmt(DateTime(thisStart.year, thisStart.month - 1, 1));
        break;
      case 'Year':
        prevFrom = fmt(DateTime(now.year - 1, 1, 1));
        prevTo = fmt(DateTime(now.year - 1, 12, 31));
        break;
    }

    final results = await Future.wait([
      Services.analytics.fetchTrend(fromDate: range['from'], toDate: range['to']),
      Services.analytics.fetchTrend(fromDate: prevFrom, toDate: prevTo),
      Services.analytics.fetchExpenseBreakdown(fromDate: range['from'], toDate: range['to']),
      Services.analytics.fetchExpenseBreakdown(fromDate: prevFrom, toDate: prevTo),
      Services.analytics.fetchDebtOverview(fromDate: range['from'], toDate: range['to']),
      Services.analytics.fetchPumpPerformance(fromDate: range['from'], toDate: range['to']),
      Services.analytics.fetchFuelPerformance(fromDate: range['from'], toDate: range['to']),
      Services.analytics.fetchExternalPayments(fromDate: range['from'], toDate: range['to']),
    ]);

    if (!mounted) return;

    final insights = AiInsightEngine.generate(
      tanks: _tankLevels,
      currentPeriod: results[0] as List<DayAnalytics>,
      previousPeriod: results[1] as List<DayAnalytics>,
      expenseBreakdown: results[2] as List<ExpenseCategoryTotal>,
      previousExpenseBreakdown: results[3] as List<ExpenseCategoryTotal>,
      debts: results[4] as List<DebtSummary>,
      pumpPerformance: results[5] as List<PumpPerformance>,
      fuelPerformance: results[6] as List<FuelPerformance>,
      externalPayments: results[7] as List<ExternalPaymentSummary>,
      currentPeriodLabel: _insightPeriod.toLowerCase(),
    );

    setState(() {
      _aiInsights = insights;
      _loadingAiInsights = false;
    });
  }

  Future<void> _loadExternalPayments() async {
    setState(() => _loadingExternalPayments = true);
    final range = _computeInsightDateRange();
    final data = await Services.analytics.fetchExternalPayments(
        fromDate: range['from'], toDate: range['to']);
    if (!mounted) return;
    setState(() {
      _externalPayments = data;
      _loadingExternalPayments = false;
    });
  }

  Future<void> _loadCashFlow() async {
    setState(() => _loadingCashFlow = true);
    final range = _computeInsightDateRange();
    final data = await Services.analytics.fetchCashFlow(
        fromDate: range['from'], toDate: range['to']);
    if (!mounted) return;
    setState(() {
      _cashFlow = data;
      _loadingCashFlow = false;
    });
  }

  Future<void> _loadTopSuppliers() async {
  setState(() => _loadingTopSuppliers = true);
    final range = _computeInsightDateRange();
    final data = await Services.analytics.fetchTopSuppliers(
        fromDate: range['from'], toDate: range['to']);
    if (!mounted) return;
    setState(() {
      _topSuppliers = data;
      _loadingTopSuppliers = false;
    });
  }

  Future<void> _loadExpenseBreakdown() async {
    setState(() => _loadingExpenseBreakdown = true);
    final range = _computeInsightDateRange();
    final data = await Services.analytics.fetchExpenseBreakdown(
        fromDate: range['from'], toDate: range['to']);
    if (!mounted) return;
    setState(() {
      _expenseBreakdown = data;
      _loadingExpenseBreakdown = false;
    });
  }

  Future<void> _loadDebtOverview() async {
    setState(() => _loadingDebtOverview = true);
    final range = _computeInsightDateRange();
    final data = await Services.analytics.fetchDebtOverview(
        fromDate: range['from'], toDate: range['to']);
    if (!mounted) return;
    setState(() {
      _debtOverview = data;
      _loadingDebtOverview = false;
    });
  }

  Future<void> _loadPumpPerformance() async {
    setState(() => _loadingPumpPerformance = true);
    final range = _computeInsightDateRange();
    final data =
        await Services.analytics.fetchPumpPerformance(fromDate: range['from'], toDate: range['to']);
    if (!mounted) return;
    setState(() {
      _pumpPerformance = data;
      _loadingPumpPerformance = false;
    });
  }

  Future<void> _loadFuelPerformance() async {
    setState(() => _loadingFuelPerformance = true);
    final range = _computeInsightDateRange();
    final data = await Services.analytics.fetchFuelPerformance(
      fromDate: range['from'], toDate: range['to']);
    if (!mounted) return;
    setState(() {
      _fuelPerformance = data;
      _loadingFuelPerformance = false;
    });
  }


  Future<void> _loadInsightTrend() async {
    setState(() => _loadingInsightTrend = true);
    final range = _computeInsightDateRange();
    final data = await Services.analytics.fetchTrend(fromDate: range['from'], toDate: range['to']);
    if (!mounted) return;
    setState(() {
      _insightTrend = data;
      _loadingInsightTrend = false;
    });
  }

 

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodSelector(),
          const SizedBox(height: 20),
          _buildKpiCards(),
          const SizedBox(height: 24),
          SizedBox(
            height: 340,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildPumpChartSection()),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _buildTankLevelsSection()),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _buildFuelPerformanceSection()),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildTopSuppliersSection()),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: _buildExpenseBreakdownSection()),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _buildDebtOverviewSection()),
              ],
            ),
          ),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: _buildExternalPaymentsSection()),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: _buildCashFlowSection()),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildAiInsightsSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }


  Widget _buildAiInsightsSection() {
    final iconFor = (InsightType type) {
      switch (type) {
        case InsightType.warning: return Icons.warning_amber_rounded;
        case InsightType.positive: return Icons.check_circle_outline;
        case InsightType.info: return Icons.info_outline;
      }
    };

    final colorFor = (InsightType type) {
      switch (type) {
        case InsightType.warning: return Colors.orange;
        case InsightType.positive: return Colors.greenAccent;
        case InsightType.info: return Colors.cyan;
      }
    };

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              const Text(
                'AI Insights',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: const Text(
                  'Rule-based',
                  style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              Text(
                _insightPeriod,
                style: const TextStyle(color: textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingAiInsights)
            const Center(child: CircularProgressIndicator())
          else if (_aiInsights.isEmpty)
            const Center(
              child: Text(
                'No insights available for this period yet.',
                style: TextStyle(color: textSecondary),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _aiInsights.map((insight) {
                final color = colorFor(insight.type);
                final icon = iconFor(insight.type);
                return Container(
                  width: 340,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: color, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              insight.title,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              insight.detail,
                              style: const TextStyle(color: textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTopSuppliersSection() {
    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Top Suppliers', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              _viewDetailsButton(() {
                final range = _computeInsightDateRange();
                _showDetailDialog(
                  'All Deliveries',
                  Services.analytics.fetchDeliveryDetail(fromDate: range['from'], toDate: range['to']),
                  (row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      SizedBox(width: 80, child: Text(row['business_date'] as String, style: const TextStyle(color: textSecondary, fontSize: 11))),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(row['supplier'] as String, style: const TextStyle(color: textPrimary, fontSize: 12)),
                          Text('${row['fuel_type']} • ${(row['liters'] as num).toStringAsFixed(0)}L', style: const TextStyle(color: textSecondary, fontSize: 10)),
                        ]),
                      ),
                      Text(moneyFmt.format((row['total_cost'] as num).toDouble()), style: const TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                );
              }),
            ],
          ),
          const Text('by delivery value', style: TextStyle(color: textSecondary, fontSize: 11)),
          const SizedBox(height: 12),
          if (_loadingTopSuppliers)
            const Center(child: CircularProgressIndicator())
          else if (_topSuppliers.isEmpty)
            const Center(child: Text('No deliveries', style: TextStyle(color: textSecondary)))
          else
            ...(_topSuppliers.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              final maxVal = _topSuppliers.first.totalDeliveryValue;
              final barWidth = maxVal > 0 ? s.totalDeliveryValue / maxVal : 0.0;
              final colors = [Colors.orange, Colors.cyan, Colors.green, Colors.purpleAccent, Colors.redAccent];
              final color = colors[i % colors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${i + 1}. ${s.supplier}',
                            style: const TextStyle(color: textPrimary, fontSize: 12)),
                        Text(moneyFmt.format(s.totalDeliveryValue),
                            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: barWidth,
                        minHeight: 6,
                        backgroundColor: Colors.white.withOpacity(0.06),
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            })),
        ],
      ),
    );
  }

  Widget _buildExternalPaymentsSection() {
    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('External Payments', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              _viewDetailsButton(() {
                final range = _computeInsightDateRange();
                _showDetailDialog(
                  'All External Payments',
                  Services.analytics.fetchExternalPaymentDetail(fromDate: range['from'], toDate: range['to']),
                  (row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      SizedBox(width: 80, child: Text(row['business_date'] as String, style: const TextStyle(color: textSecondary, fontSize: 11))),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(row['supplier'] as String, style: const TextStyle(color: textPrimary, fontSize: 12)),
                          Text('${row['fuel_type']} • ${row['kind']}', style: const TextStyle(color: textSecondary, fontSize: 10)),
                        ]),
                      ),
                      Text(moneyFmt.format((row['amount'] as num).toDouble()), style: const TextStyle(color: Colors.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          if (_loadingExternalPayments)
            const Center(child: CircularProgressIndicator())
          else if (_externalPayments.isEmpty)
            const Center(
              child: Text('No external payments', style: TextStyle(color: textSecondary)),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.separated(
                itemCount: _externalPayments.length,
                separatorBuilder: (_, __) => const Divider(color: panelBorder, height: 1),
                itemBuilder: (_, i) {
                  final p = _externalPayments[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.supplier,
                                  style: const TextStyle(color: textPrimary, fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                              Text('${p.fuelType} • ${p.kind}',
                                  style: const TextStyle(color: textSecondary, fontSize: 10)),
                            ],
                          ),
                        ),
                        Text(
                          moneyFmt.format(p.amount),
                          style: const TextStyle(
                              color: Colors.cyan, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _viewDetailsButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('View Details', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w600)),
            SizedBox(width: 2),
            Icon(Icons.chevron_right, color: Colors.orange, size: 14),
          ],
        ),
      ),
    );
  }

  Future<void> _showDetailDialog(
    String title,
    Future<List<Map<String, dynamic>>> future,
    Widget Function(Map<String, dynamic> row) rowBuilder,
  ) async {
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: panelBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: panelBorder)),
        child: SizedBox(
          width: 480,
          height: 520,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16))),
                    IconButton(icon: const Icon(Icons.close, color: textSecondary), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const Divider(color: panelBorder),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final rows = snapshot.data ?? [];
                      if (rows.isEmpty) {
                        return const Center(child: Text('No records for this period', style: TextStyle(color: textSecondary)));
                      }
                      return ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(color: panelBorder, height: 1),
                        itemBuilder: (_, i) => rowBuilder(rows[i]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCashFlowSection() {
    if (_loadingCashFlow || _cashFlow == null) {
      return Container(
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: panelBorder),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final cf = _cashFlow!;
    final net = cf.netCashFlow;

    Widget cashRow(String label, double value, Color color, {bool isBold = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                  color: isBold ? textPrimary : textSecondary,
                  fontSize: isBold ? 13 : 12,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
                )),
            Text(
              '${value >= 0 ? '+' : ''}${moneyFmt.format(value)}',
              style: TextStyle(
                color: color,
                fontSize: isBold ? 15 : 12,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cash Flow Summary',
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 16),
          cashRow('Sales Revenue', cf.salesRevenue, Colors.green),
          cashRow('Expenses', -cf.expenses, Colors.redAccent),
          cashRow('Debt Settlements', -cf.debtSettlements, Colors.orange),
          cashRow('External Payments', -cf.externalPayments, Colors.orange),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: panelBorder),
          ),
          cashRow('Net Cash Flow', net, net >= 0 ? Colors.greenAccent : Colors.redAccent, isBold: true),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: cf.salesRevenue > 0
                  ? ((cf.expenses + cf.debtSettlements + cf.externalPayments) / cf.salesRevenue).clamp(0.0, 1.0)
                  : 0.0,
              minHeight: 8,
              backgroundColor: Colors.green.withOpacity(0.3),
              color: Colors.redAccent.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseBreakdownSection() {
    if (_loadingExpenseBreakdown) {
      return Container(
        decoration: BoxDecoration(color: panelBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: panelBorder)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_expenseBreakdown.isEmpty) {
      return Container(
        decoration: BoxDecoration(color: panelBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: panelBorder)),
        child: const Center(child: Text('No expenses', style: TextStyle(color: textSecondary))),
      );
    }

    final total = _expenseBreakdown.fold(0.0, (s, e) => s + e.amount);
    final categoryColors = [
      Colors.orange, Colors.cyan, Colors.green, Colors.purpleAccent,
      Colors.redAccent, Colors.amber, Colors.teal, Colors.pinkAccent,
    ];

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Expense Breakdown', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              _viewDetailsButton(() {
                final range = _computeInsightDateRange();
                _showDetailDialog(
                  'All Expenses',
                  Services.analytics.fetchExpenseDetail(fromDate: range['from'], toDate: range['to']),
                  (row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      SizedBox(width: 80, child: Text(row['business_date'] as String, style: const TextStyle(color: textSecondary, fontSize: 11))),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(row['category'] as String, style: const TextStyle(color: textPrimary, fontSize: 12)),
                          if ((row['comment'] as String?)?.isNotEmpty ?? false)
                            Text(row['comment'] as String, style: const TextStyle(color: textSecondary, fontSize: 10)),
                        ]),
                      ),
                      Text(moneyFmt.format((row['amount'] as num).toDouble()), style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sections: _expenseBreakdown.asMap().entries.map((entry) {
                        final i = entry.key;
                        final e = entry.value;
                        final share = total > 0 ? (e.amount / total) * 100 : 0.0;
                        final color = categoryColors[i % categoryColors.length];
                        return PieChartSectionData(
                          value: e.amount,
                          color: color,
                          title: share >= 8 ? '${share.toStringAsFixed(0)}%' : '',
                          titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          radius: 55,
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _expenseBreakdown.asMap().entries.map((entry) {
                        final i = entry.key;
                        final e = entry.value;
                        final share = total > 0 ? (e.amount / total) * 100 : 0.0;
                        final color = categoryColors[i % categoryColors.length];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(width: 8, height: 8,
                                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(e.category,
                                    style: const TextStyle(color: textSecondary, fontSize: 10),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Text('${share.toStringAsFixed(0)}%',
                                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('Total: ${moneyFmt.format(total)}',
              style: const TextStyle(color: textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildDebtOverviewSection() {
    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Debt Overview', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              _viewDetailsButton(() {
                final range = _computeInsightDateRange();
                _showDetailDialog(
                  'All Debts',
                  Services.analytics.fetchDebtDetail(fromDate: range['from'], toDate: range['to']),
                  (row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      SizedBox(width: 80, child: Text(row['business_date'] as String, style: const TextStyle(color: textSecondary, fontSize: 11))),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(row['supplier'] as String, style: const TextStyle(color: textPrimary, fontSize: 12)),
                          Text(row['fuel_type'] as String, style: const TextStyle(color: textSecondary, fontSize: 10)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(moneyFmt.format((row['amount'] as num).toDouble()),
                            style: TextStyle(color: (row['settled'] as bool) ? Colors.green : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text((row['settled'] as bool) ? 'Settled' : 'Unpaid',
                            style: TextStyle(color: (row['settled'] as bool) ? Colors.green : Colors.redAccent, fontSize: 10)),
                      ]),
                    ]),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          if (_loadingDebtOverview)
            const Center(child: CircularProgressIndicator())
          else if (_debtOverview.isEmpty)
            const Center(child: Text('No debts', style: TextStyle(color: textSecondary)))
          else
            Expanded(
              child: ListView.separated(
                itemCount: _debtOverview.length,
                separatorBuilder: (_, __) => const Divider(color: panelBorder, height: 1),
                itemBuilder: (_, i) {
                  final d = _debtOverview[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: d.settled ? Colors.green : Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.supplier,
                                  style: const TextStyle(color: textPrimary, fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                              Text(d.fuelType,
                                  style: const TextStyle(color: textSecondary, fontSize: 10)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(moneyFmt.format(d.amount),
                                style: TextStyle(
                                  color: d.settled ? Colors.green : Colors.redAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                )),
                            Text(d.settled ? 'Settled' : 'Unpaid',
                                style: TextStyle(
                                  color: d.settled ? Colors.green : Colors.redAccent,
                                  fontSize: 10,
                                )),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTankLevelsSection() {
    final tanks = _tankLevels;
    final fuelColors = {
      'PMS': Colors.green,
      'AGO': Colors.orange,
      'DPK': Colors.cyan,
      'Gas': Colors.purpleAccent,
    };

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tank Levels', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              _viewDetailsButton(() {
                final range = _computeInsightDateRange();
                _showDetailDialog(
                  'Tank Level History',
                  Services.analytics.fetchTankSnapshotDetail(fromDate: range['from'], toDate: range['to']),
                  (row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      SizedBox(width: 80, child: Text(row['business_date'] as String, style: const TextStyle(color: textSecondary, fontSize: 11))),
                      Expanded(child: Text(row['fuel_type'] as String, style: const TextStyle(color: textPrimary, fontSize: 12))),
                      Text('${(row['current_level'] as num).toStringAsFixed(0)} / ${(row['capacity'] as num).toStringAsFixed(0)} L',
                          style: const TextStyle(color: textSecondary, fontSize: 11)),
                      const SizedBox(width: 8),
                      Text('${(row['percentage'] as num).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          ...tanks.map((t) {
            final p = t.percentage;
            final color = p > 50
                ? Colors.green
                : p > 20
                    ? Colors.orange
                    : Colors.red;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t.fuelType,
                          style: const TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                      Text('${p.toInt()}%',
                          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: p / 100,
                      minHeight: 10,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${t.currentLevel.toStringAsFixed(0)} / ${t.capacity.toStringAsFixed(0)} L',
                    style: const TextStyle(color: textSecondary, fontSize: 10),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFuelPerformanceSection() {
    if (_loadingFuelPerformance) {
      return Container(
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: panelBorder),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_fuelPerformance.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: panelBorder),
        ),
        child: const Center(
          child: Text('No fuel data', style: TextStyle(color: textSecondary)),
        ),
      );
    }

    final totalRevenue = _fuelPerformance.fold(0.0, (s, f) => s + f.revenue);
    final fuelColors = {
      'PMS': Colors.green,
      'AGO': Colors.orange,
      'DPK': Colors.cyan,
      'Gas': Colors.purpleAccent,
    };

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fuel Performance',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: PieChart(
              PieChartData(
                sections: _fuelPerformance.map((f) {
                  final share = totalRevenue > 0 ? (f.revenue / totalRevenue) * 100 : 0.0;
                  final color = fuelColors[f.fuelType] ?? Colors.grey;
                  return PieChartSectionData(
                    value: f.revenue,
                    color: color,
                    title: '${share.toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    radius: 55,
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 28,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _fuelPerformance.map((f) {
              final color = fuelColors[f.fuelType] ?? Colors.grey;
              final share = totalRevenue > 0 ? (f.revenue / totalRevenue) * 100 : 0.0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(
                    '${f.fuelType} ${share.toStringAsFixed(0)}%',
                    style: const TextStyle(color: textSecondary, fontSize: 10),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        pillButton('Today', _insightPeriod == 'Today', () {
          setState(() => _insightPeriod = 'Today');
          _reloadAll();
        }),
        const SizedBox(width: 8),
        pillButton('Week', _insightPeriod == 'Week', () {
          setState(() => _insightPeriod = 'Week');
          _reloadAll();
        }),
        const SizedBox(width: 8),
        pillButton('Month', _insightPeriod == 'Month', () {
          setState(() => _insightPeriod = 'Month');
          _reloadAll();
        }),
        const SizedBox(width: 8),
        pillButton('Year', _insightPeriod == 'Year', () {
          setState(() => _insightPeriod = 'Year');
          _reloadAll();
        }),
        const SizedBox(width: 8),
        pillButton('Custom', _insightPeriod == 'Custom', () {
          setState(() => _insightPeriod = 'Custom');
          _reloadAll();
        }),
        if (_insightPeriod == 'Custom') ...[
          const SizedBox(width: 16),
          TextButton(
            onPressed: () async {
              final picked = await showThemedDatePicker(context, initial: _customFrom);
              if (picked != null) {
                setState(() => _customFrom = picked);
                if (_customTo != null) _reloadAll();
              }
            },
            child: Text(
              _customFrom == null ? 'From' : DateFormat('MMM d, yyyy').format(_customFrom!),
              style: const TextStyle(color: textSecondary),
            ),
          ),
          const Text('→', style: TextStyle(color: textSecondary)),
          TextButton(
            onPressed: () async {
              final picked = await showThemedDatePicker(context, initial: _customTo);
              if (picked != null) {
                setState(() => _customTo = picked);
                if (_customFrom != null) _reloadAll();
              }
            },
            child: Text(
              _customTo == null ? 'To' : DateFormat('MMM d, yyyy').format(_customTo!),
              style: const TextStyle(color: textSecondary),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildKpiCards() {
    final totalRevenue = _insightTrend.fold(0.0, (s, d) => s + d.revenue);
    final totalExpense = _insightTrend.fold(0.0, (s, d) => s + d.expense);
    final totalNet = _insightTrend.fold(0.0, (s, d) => s + d.net);

    return Row(
      children: [
        Expanded(child: summaryCard('Revenue', totalRevenue, Colors.green)),
        const SizedBox(width: 12),
        Expanded(child: summaryCard('Expenses', totalExpense, Colors.orange)),
        const SizedBox(width: 12),
        Expanded(child: summaryCard('Net Profit', totalNet, Colors.purpleAccent)),
        const SizedBox(width: 12),
        Expanded(child: summaryCard('Outstanding Debt', Services.debt.totalDebt, Colors.redAccent)),
      ],
    );
  }

  Widget _buildPumpChartSection() {
    if (_loadingPumpPerformance) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pumpPerformance.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: panelBorder),
        ),
        child: const Center(
          child: Text('No pump sales data for this period', style: TextStyle(color: textSecondary)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sales by Pump', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              _viewDetailsButton(() {
                final range = _computeInsightDateRange();
                _showDetailDialog(
                  'All Pump Sales',
                  Services.analytics.fetchSalesDetail(fromDate: range['from'], toDate: range['to']),
                  (row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      SizedBox(width: 80, child: Text(row['business_date'] as String, style: const TextStyle(color: textSecondary, fontSize: 11))),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Pump ${row['pump_no']} • ${row['fuel_type']}', style: const TextStyle(color: textPrimary, fontSize: 12)),
                          Text('${(row['liters'] as num).toStringAsFixed(0)}L @ ₦${row['unit_price']}', style: const TextStyle(color: textSecondary, fontSize: 10)),
                        ]),
                      ),
                      Text(moneyFmt.format((row['total_amount'] as num).toDouble()), style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: panelBorder, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 56,
                      getTitlesWidget: (value, meta) => Text(
                        NumberFormat.compact().format(value),
                        style: const TextStyle(color: textSecondary, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= _pumpPerformance.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Pump ${_pumpPerformance[idx].pumpNo}',
                            style: const TextStyle(color: textSecondary, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: _pumpPerformance.asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: p.revenue,
                        color: Colors.green,
                        width: 28,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}