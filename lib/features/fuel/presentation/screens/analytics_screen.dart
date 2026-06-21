// lib/features/fuel/presentation/screens/analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/services/service_registry.dart';
import '../../../../core/services/analytics_service.dart';

const panelBg = Color(0xFF0f172a);
const panelBg2 = Color(0xFF111827);
const panelBorder = Color(0xFF1f2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);

class AnalyticsScreen extends StatefulWidget {
  final VoidCallback onBack;

  const AnalyticsScreen({super.key, required this.onBack});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _showTrend = true;

  final money = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  bool _loadingTrend = true;
  List<DayAnalytics> _trend = [];

  bool _loadingDates = true;
  List<String> _availableDates = [];
  String? _selectedDate;
  Map<String, dynamic>? _dayDetail;
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _loadTrend();
    _loadAvailableDates();
  }

  Future<void> _loadTrend() async {
    setState(() => _loadingTrend = true);
    final data = await Services.analytics.fetchTrend();
    if (!mounted) return;
    setState(() {
      _trend = data;
      _loadingTrend = false;
    });
  }

  Future<void> _loadAvailableDates() async {
    setState(() => _loadingDates = true);
    final dates = await Services.analytics.fetchAvailableDates();
    if (!mounted) return;
    setState(() {
      _availableDates = dates;
      _loadingDates = false;
      if (dates.isNotEmpty) {
        _selectedDate = dates.first;
        _loadDayDetail(dates.first);
      }
    });
  }

  Future<void> _loadDayDetail(String date) async {
    setState(() => _loadingDetail = true);
    final detail = await Services.analytics.fetchDayDetail(date);
    if (!mounted) return;
    setState(() {
      _dayDetail = detail;
      _loadingDetail = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0b1220),
      body: Column(
        children: [
          _buildTopBar(),
          _buildToggle(),
          Expanded(
            child: _showTrend ? _buildTrendView() : _buildDayDetailView(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: panelBg2,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Text(
            'Analytics',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      color: const Color(0xFF1e293b),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          _toggleButton('Trends', _showTrend, () => setState(() => _showTrend = true)),
          const SizedBox(width: 12),
          _toggleButton('Day Detail', !_showTrend, () => setState(() => _showTrend = false)),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.orange.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? Colors.orange : panelBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.orange : textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTrendView() {
    if (_loadingTrend) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_trend.isEmpty) {
      return const Center(
        child: Text('No sent data yet', style: TextStyle(color: textSecondary)),
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
          Row(
            children: [
              Expanded(child: _summaryCard('Total Revenue', totalRevenue, Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard('Total Expense', totalExpense, Colors.redAccent)),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard('Total Delivery Cost', totalDelivery, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard(
                  'Net',
                  totalNet,
                  totalNet >= 0 ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
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
        ],
      ),
    );
  }

  Widget _summaryCard(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            money.format(value),
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
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
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
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
        _legendItem('Revenue', Colors.green),
        _legendItem('Expense', Colors.redAccent),
        _legendItem('Delivery Cost', Colors.orange),
        _legendItem('Net', Colors.cyan),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildDayDetailView() {
    if (_loadingDates) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_availableDates.isEmpty) {
      return const Center(
        child: Text('No sent data yet', style: TextStyle(color: textSecondary)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Business Date:', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedDate,
                dropdownColor: panelBg2,
                style: const TextStyle(color: textPrimary),
                items: _availableDates
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selectedDate = v);
                  _loadDayDetail(v);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _loadingDetail
                ? const Center(child: CircularProgressIndicator())
                : _dayDetail == null
                    ? const Center(
                        child: Text('No data for this date', style: TextStyle(color: textSecondary)),
                      )
                    : _buildDetailContent(_dayDetail!),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailContent(Map<String, dynamic> payload) {
    final sales = (payload['sales'] as List? ?? []);
    final deliveries = (payload['deliveries'] as List? ?? []);
    final debts = (payload['debts'] as List? ?? []);
    final settlements = (payload['settlements'] as List? ?? []);
    final expenses = (payload['expenses'] as List? ?? []);
    final externalPayments = (payload['externalPayments'] as List? ?? []);
    final tankSnapshot = (payload['tankSnapshot'] as List? ?? []);

    final revenue = sales.fold<double>(0.0, (s, x) => s + ((x['totalAmount'] as num?)?.toDouble() ?? 0.0));
    final expenseTotal = expenses.fold<double>(0.0, (s, x) => s + ((x['amount'] as num?)?.toDouble() ?? 0.0));
    final deliveryTotal = deliveries.fold<double>(0.0, (s, x) => s + ((x['totalCost'] as num?)?.toDouble() ?? 0.0));
    final externalTotal = externalPayments.fold<double>(0.0, (s, x) => s + ((x['amount'] as num?)?.toDouble() ?? 0.0));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _summaryCard('Revenue', revenue, Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard('Expense', expenseTotal, Colors.redAccent)),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard('Delivery Cost', deliveryTotal, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard('External Payments', externalTotal, Colors.cyan)),
            ],
          ),
          const SizedBox(height: 20),
          _sectionList(
            'Sales (${sales.length})',
            sales,
            (x) => '${x['fuelType']} • Pump ${x['pumpNo']} • ${(x['liters'] as num).toStringAsFixed(0)}L',
            (x) => (x['totalAmount'] as num).toDouble(),
          ),
          _sectionList(
            'Deliveries (${deliveries.length})',
            deliveries,
            (x) => '${x['supplier']} • ${x['fuelType']} • ${(x['liters'] as num).toStringAsFixed(0)}L',
            (x) => (x['totalCost'] as num).toDouble(),
          ),
          _sectionList(
            'Debts (${debts.length})',
            debts,
            (x) => '${x['supplier']} • ${x['fuelType']}',
            (x) => (x['amount'] as num).toDouble(),
          ),
          _sectionList(
            'Settlements (${settlements.length})',
            settlements,
            (x) => '${x['supplier']} • ${x['fuelType']}',
            (x) => (x['paidAmount'] as num).toDouble(),
          ),
          _sectionList(
            'Expenses (${expenses.length})',
            expenses,
            (x) => '${x['category']}${(x['comment'] as String?)?.isNotEmpty == true ? " • ${x['comment']}" : ""}',
            (x) => (x['amount'] as num).toDouble(),
          ),
          _sectionList(
            'External Payments (${externalPayments.length})',
            externalPayments,
            (x) => '${x['supplier']} • ${x['fuelType']} • ${x['kind']}',
            (x) => (x['amount'] as num).toDouble(),
          ),
          const SizedBox(height: 8),
          const Text('Tank Snapshot', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: tankSnapshot.map<Widget>((t) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: panelBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: panelBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['fuelType'], style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        '${(t['currentLevel'] as num).toStringAsFixed(0)} / ${(t['capacity'] as num).toStringAsFixed(0)} L',
                        style: const TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionList(
    String title,
    List items,
    String Function(dynamic) subtitleBuilder,
    double Function(dynamic) amountBuilder,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...items.map((x) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: panelBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: panelBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitleBuilder(x),
                      style: const TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ),
                  Text(
                    money.format(amountBuilder(x)),
                    style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}