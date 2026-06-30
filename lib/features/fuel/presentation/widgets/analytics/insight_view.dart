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

  bool _loadingPumpPerformance = true;
  List<PumpPerformance> _pumpPerformance = [];
  bool _loadingFuelPerformance = true;
  List<FuelPerformance> _fuelPerformance = [];

  bool _loadingInsightTrend = true;
  List<DayAnalytics> _insightTrend = [];

  @override
  void initState() {
    super.initState();
    _loadPumpPerformance();
    _loadInsightTrend();
    _loadFuelPerformance();
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
      default:
        return {'from': null, 'to': null};
    }
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

  void _reloadAll() {
    _loadPumpPerformance();
    _loadInsightTrend();
    _loadFuelPerformance();
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
        ],
      ),
    );
  }

  Widget _buildTankLevelsSection() {
    final tanks = Services.tank.allTanks;
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
            'Tank Levels',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
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
          const Text(
            'Sales by Pump',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
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