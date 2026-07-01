// lib/features/fuel/presentation/widgets/analytics/analytics_trends_view.dart
//
// The "Trends" tab of the Analytics screen: period selector (Week/
// Month/Year/Custom), summary KPI cards, the Revenue/Expense/Delivery/
// Net line chart, and the Fuel Performance breakdown (cards + pie).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../../core/services/analytics_service.dart';
import '../../../../../core/services/service_registry.dart';
import 'shared.dart';


class AnalyticsTrendsView extends StatefulWidget {
  const AnalyticsTrendsView({super.key});

  @override
  State<AnalyticsTrendsView> createState() => _AnalyticsTrendsViewState();
}

class _AnalyticsTrendsViewState extends State<AnalyticsTrendsView> {
  String _period = 'Week'; // 'Week' | 'Month' | 'Year' | 'Custom'
  DateTime? _customFrom;
  DateTime? _customTo;

  bool _loadingTrend = true;
  List<DayAnalytics> _trend = [];

  bool _loadingFuelPerformance = true;
  List<FuelPerformance> _fuelPerformance = [];

  bool _loadingPriceTrend = true;
  List<FuelPriceTrend> _priceTrend = [];

  @override
  void initState() {
    super.initState();
    _loadTrend();
    _loadFuelPerformance();
    _loadPriceTrend();
  }

  Map<String, String?> _computeDateRange() {
    final now = DateTime.now();
    String fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

    switch (_period) {
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

  Future<void> _loadPriceTrend() async {
  setState(() => _loadingPriceTrend = true);
    final range = _computeDateRange();
    final data = await Services.analytics.fetchPriceTrend(
        fromDate: range['from'], toDate: range['to']);
    if (!mounted) return;
    setState(() {
      _priceTrend = data;
      _loadingPriceTrend = false;
    });
  }

  Future<void> _loadTrend() async {
    setState(() => _loadingTrend = true);
    final range = _computeDateRange();
    final data = await Services.analytics.fetchTrend(fromDate: range['from'], toDate: range['to']);
    if (!mounted) return;
    setState(() {
      _trend = data;
      _loadingTrend = false;
    });
  }

  Future<void> _loadFuelPerformance() async {
    setState(() => _loadingFuelPerformance = true);
    final range = _computeDateRange();
    final data = await Services.analytics.fetchFuelPerformance(fromDate: range['from'], toDate: range['to']);
    if (!mounted) return;
    setState(() {
      _fuelPerformance = data;
      _loadingFuelPerformance = false;
    });
  }

  void _reloadAll() {
    _loadTrend();
    _loadFuelPerformance();
    _loadPriceTrend();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingTrend) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_trend.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 40),
            const Center(
              child: Text('No sent data yet for this period', style: TextStyle(color: textSecondary)),
            ),
          ],
        ),
      );
    }

    final totalRevenue = _trend.fold(0.0, (s, d) => s + d.revenue);
    final totalExpense = _trend.fold(0.0, (s, d) => s + d.expense);
    final totalDelivery = _trend.fold(0.0, (s, d) => s + d.deliveryCost);
    final totalNet = _trend.fold(0.0, (s, d) => s + d.net);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodSelector(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: summaryCard('Total Revenue', totalRevenue, Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: summaryCard('Total Expense', totalExpense, Colors.redAccent)),
              const SizedBox(width: 12),
              Expanded(child: summaryCard('Total Delivery Cost', totalDelivery, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(
                child: summaryCard('Net', totalNet, totalNet >= 0 ? Colors.greenAccent : Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A: Revenue/Expense/Delivery/Net chart
                Expanded(
                  flex: 3,
                  child: Container(
                    height: double.infinity,
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
                          'Revenue, Expense, Delivery & Net Over Time',
                          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        Expanded(child: _buildChart()),
                        const SizedBox(height: 12),
                        _buildLegend(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // B: Fuel Performance
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: double.infinity,
                    child: _buildFuelPerformanceSection(),
                  ),
                ),
                const SizedBox(width: 16),
                // C: Price Trend
                Expanded(
                  flex: 2,
                  child: _buildPriceTrendSection(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        pillButton('Week', _period == 'Week', () {
          setState(() => _period = 'Week');
          _reloadAll();
        }),
        const SizedBox(width: 8),
        pillButton('Month', _period == 'Month', () {
          setState(() => _period = 'Month');
          _reloadAll();
        }),
        const SizedBox(width: 8),
        pillButton('Year', _period == 'Year', () {
          setState(() => _period = 'Year');
          _reloadAll();
        }),
        const SizedBox(width: 8),
        pillButton('Custom', _period == 'Custom', () {
          setState(() => _period = 'Custom');
          _reloadAll();
        }),
        if (_period == 'Custom') ...[
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

  Widget _buildChart() {
    final spotsRevenue = <FlSpot>[];
    final spotsExpense = <FlSpot>[];
    final spotsDelivery = <FlSpot>[];
    final spotsNet = <FlSpot>[];

    for (int i = 0; i < _trend.length; i++) {
      final d = _trend[i];
      spotsRevenue.add(FlSpot(i.toDouble(), d.revenue));
      spotsExpense.add(FlSpot(i.toDouble(), d.expense));
      spotsDelivery.add(FlSpot(i.toDouble(), d.deliveryCost));
      spotsNet.add(FlSpot(i.toDouble(), d.net));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: panelBorder, strokeWidth: 1),
        ),
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
              interval: (_trend.length / 8).ceil().clamp(1, _trend.length).toDouble(),
              getTitlesWidget: (value, meta) {
                final idx = value.round();
                if (idx < 0 || idx >= _trend.length) return const SizedBox.shrink();

                final d = DateTime.tryParse(_trend[idx].businessDate);
                final label = d != null ? DateFormat('MMM d').format(d) : '';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label, style: const TextStyle(color: textSecondary, fontSize: 10)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          _line(spotsRevenue, Colors.green),
          _line(spotsExpense, Colors.redAccent),
          _line(spotsDelivery, Colors.orange),
          _line(spotsNet, Colors.cyan),
        ],
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      color: color,
      barWidth: 2.5,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(show: false),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      children: [
        legendItem('Revenue', Colors.green),
        legendItem('Expense', Colors.redAccent),
        legendItem('Delivery Cost', Colors.orange),
        legendItem('Net', Colors.cyan),
      ],
    );
  }

  Widget _buildPriceTrendSection() {
    if (_loadingPriceTrend) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_priceTrend.isEmpty) {
      return const SizedBox.shrink();
    }

    // Collect all fuel types that appear across the period
    final fuelTypes = <String>{};
    for (final day in _priceTrend) {
      fuelTypes.addAll(day.avgPriceByFuel.keys);
    }
    final fuels = fuelTypes.toList()..sort();

    final fuelColors = {
      'PMS': Colors.green,
      'AGO': Colors.orange,
      'DPK': Colors.cyan,
      'Gas': Colors.purpleAccent,
    };

    // Build one line per fuel type
    final lines = <LineChartBarData>[];
    for (final fuel in fuels) {
      final spots = <FlSpot>[];
      for (int i = 0; i < _priceTrend.length; i++) {
        final price = _priceTrend[i].avgPriceByFuel[fuel];
        if (price != null && price > 0) {
          spots.add(FlSpot(i.toDouble(), price));
        }
      }
      if (spots.isEmpty) continue;

      lines.add(LineChartBarData(
        spots: spots,
        isCurved: false,
        color: fuelColors[fuel] ?? Colors.grey,
        barWidth: 2.5,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(show: false),
      ));
    }

      return Container(
        height: double.infinity, // fills the Expanded slot
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
            'Price Trend (₦ per Litre)',
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
                        '₦${NumberFormat.compact().format(value)}',
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
                        if (idx < 0 || idx >= fuels.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(fuels[idx], style: const TextStyle(color: textSecondary, fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: fuels.asMap().entries.map((entry) {
                  final i = entry.key;
                  final fuel = entry.value;
                  final color = fuelColors[fuel] ?? Colors.grey;
                  // Average price across all days for this fuel
                  final prices = _priceTrend
                      .map((d) => d.avgPriceByFuel[fuel])
                      .whereType<double>()
                      .where((p) => p > 0)
                      .toList();
                  final avgPrice = prices.isEmpty
                      ? 0.0
                      : prices.reduce((a, b) => a + b) / prices.length;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: avgPrice,
                        color: color,
                        width: 32,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            children: fuels.map((fuel) {
              final color = fuelColors[fuel] ?? Colors.grey;
              return legendItem(fuel, color);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelPerformanceSection() {
    if (_loadingFuelPerformance) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_fuelPerformance.isEmpty) {
      return const Center(
        child: Text('No fuel performance data yet', style: TextStyle(color: textSecondary)),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fuel Performance',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: _fuelPerformance.map((f) {
                    final share = totalRevenue > 0 ? (f.revenue / totalRevenue) * 100 : 0.0;
                    final color = fuelColors[f.fuelType] ?? Colors.grey;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.fuelType,
                                  style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  '${f.liters.toStringAsFixed(0)} L',
                                  style: const TextStyle(color: textSecondary, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                moneyFmt.format(f.revenue),
                                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              Text(
                                '${share.toStringAsFixed(1)}%',
                                style: const TextStyle(color: textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 160,
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
                            fontSize: 12,
                          ),
                          radius: 55,
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 25,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}