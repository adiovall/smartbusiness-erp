// lib/features/fuel/presentation/screens/analytics_screen.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';


import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/services/service_registry.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/reconciliation_service.dart';
import '../../../../core/services/csv_import_service.dart';

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
  int _viewIndex = 0;

  final money = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  bool _loadingTrend = true;
  List<DayAnalytics> _trend = [];

  bool _loadingFuelPerformance = true;
  List<FuelPerformance> _fuelPerformance = [];

  bool _loadingReconciliation = true;

  List<FuelDayReconciliation> _reconciliation = [];
  String? _selectedFuelType;

  bool _loadingDates = true;
  List<String> _availableDates = [];
  String? _selectedDate;
  Map<String, dynamic>? _dayDetail;
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _loadTrend();
    _loadFuelPerformance();
    _loadAvailableDates();
    _loadReconciliation();
  }

  Future<void> _loadFuelPerformance() async {
    setState(() => _loadingFuelPerformance = true);
    final data = await Services.analytics.fetchFuelPerformance();
    if (!mounted) return;
    setState(() {
      _fuelPerformance = data;
      _loadingFuelPerformance = false;
    });
  }

  Future<void> _loadReconciliation() async {
    setState(() => _loadingReconciliation = true);
    final data = await Services.reconciliation.computeAll();
    if (!mounted) return;
    setState(() {
      _reconciliation = data;
      _loadingReconciliation = false;
      if (data.isNotEmpty && _selectedFuelType == null) {
        _selectedFuelType = data.first.fuelType;
      }
    });
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

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();

    final importResult = await Services.csvImport.importCsv(content);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF020617),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Import Complete',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text('Rows processed: ${importResult.rowsProcessed}',
                  style: const TextStyle(color: Colors.white70)),
              Text('Imported: ${importResult.rowsImported}',
                  style: const TextStyle(color: Colors.greenAccent)),
              Text('Skipped: ${importResult.rowsSkipped}',
                  style: const TextStyle(color: Colors.amber)),
              if (importResult.warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Details:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: importResult.warnings
                          .map((w) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('• $w',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Refresh everything so the newly imported data shows up immediately.
    // Refresh everything so the newly imported data shows up immediately.
    _loadTrend();
    _loadFuelPerformance();
    _loadAvailableDates();
    _loadReconciliation();
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
            child: _viewIndex == 0
                ? _buildTrendView()
                : _viewIndex == 1
                    ? _buildDayDetailView()
                    : _buildReconciliationView(),
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
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _importCsv,
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Import Historical Data'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
            ),
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
          _toggleButton('Trends', _viewIndex == 0, () => setState(() => _viewIndex = 0)),
          const SizedBox(width: 12),
          _toggleButton('Day Detail', _viewIndex == 1, () => setState(() => _viewIndex = 1)),
          const SizedBox(width: 12),
          _toggleButton('Reconciliation', _viewIndex == 2, () => setState(() => _viewIndex = 2)),
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
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    height: 420,
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
                  const SizedBox(height: 20),
                  _buildFuelPerformanceSection(),
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

  Widget _buildReconciliationView() {
    if (_loadingReconciliation) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reconciliation.isEmpty) {
      return const Center(
        child: Text(
          'Not enough sent days yet to reconcile tank levels.\n'
          'Reconciliation needs at least 2 sent business dates.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textSecondary),
        ),
      );
    }

    final fuelTypes = _reconciliation.map((r) => r.fuelType).toSet().toList()..sort();
    final filtered = _reconciliation.where((r) => r.fuelType == _selectedFuelType).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Fuel Type:', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedFuelType,
                dropdownColor: panelBg2,
                style: const TextStyle(color: textPrimary),
                items: fuelTypes.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (v) => setState(() => _selectedFuelType = v),
              ),
              const SizedBox(width: 24),
              const Icon(Icons.info_outline, size: 14, color: textSecondary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Each bar shows actual vs expected tank level for that day. '
                  'A bar marked unusual differs more than normal from this '
                  'fuel type\'s typical day-to-day pattern.',
                  style: TextStyle(color: textSecondary, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: panelBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: panelBorder),
              ),
              padding: const EdgeInsets.all(20),
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('No reconciliation data for this fuel type yet',
                          style: TextStyle(color: textSecondary)),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_selectedFuelType — Tank Level Gap by Day',
                          style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        Expanded(child: _buildGapChart(filtered)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 160,
                          child: SingleChildScrollView(
                            child: _buildGapTable(filtered),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGapChart(List<FuelDayReconciliation> data) {
    final barGroups = <BarChartGroupData>[];

    for (int i = 0; i < data.length; i++) {
      final r = data[i];
      final color = !r.hasBaseline
          ? Colors.white24
          : r.isUnusual
              ? Colors.redAccent
              : (r.gap.abs() < 5 ? Colors.greenAccent : Colors.amber);

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: r.gap,
              color: color,
              width: 14,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      );
    }

    return BarChart(
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
              reservedSize: 50,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: const TextStyle(color: textSecondary, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (data.length / 8).ceil().clamp(1, data.length).toDouble(),
              getTitlesWidget: (value, meta) {
                final idx = value.round();
                if (idx < 0 || idx >= data.length) return const SizedBox.shrink();

                final d = DateTime.tryParse(data[idx].businessDate);
                final label = d != null ? DateFormat('MMM d').format(d) : '';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label, style: const TextStyle(color: textSecondary, fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barGroups: barGroups,
      ),
    );
  }

  Widget _buildGapTable(List<FuelDayReconciliation> data) {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(90),
        1: FixedColumnWidth(80),
        2: FixedColumnWidth(80),
        3: FixedColumnWidth(80),
        4: FixedColumnWidth(80),
        5: FixedColumnWidth(80),
      },
      children: [
        TableRow(
          children: ['Date', 'Start', 'Delivered', 'Sold', 'Expected', 'Actual', 'Gap']
              .map((h) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(h,
                        style: const TextStyle(color: textSecondary, fontWeight: FontWeight.w600, fontSize: 11)),
                  ))
              .toList(),
        ),
        ...data.map((r) {
          final gapColor = !r.hasBaseline
              ? textSecondary
              : r.isUnusual
                  ? Colors.redAccent
                  : Colors.greenAccent;
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(r.businessDate, style: const TextStyle(color: textPrimary, fontSize: 11)),
              ),
              Text(r.startLevel.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 11)),
              Text(r.delivered.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 11)),
              Text(r.sold.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 11)),
              Text(r.expectedEnd.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 11)),
              Text(r.actualEnd.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 11)),
              Text(
                '${r.gap >= 0 ? '+' : ''}${r.gap.toStringAsFixed(0)}${r.isUnusual ? ' ⚠' : ''}',
                style: TextStyle(color: gapColor, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          );
        }),
      ],
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
              // Cards
              Expanded(
                flex: 3,
                child: Column(
                  children: _fuelPerformance.map((f) {
                    final share = totalRevenue > 0 ? (f.revenue / totalRevenue) * 100 : 0.0;
                    final color = fuelColors[f.fuelType] ?? Colors.grey;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.fuelType, style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                  '${f.liters.toStringAsFixed(0)} L',
                                  style: const TextStyle(color: textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                money.format(f.revenue),
                                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
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
              // Pie chart
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 200,
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
                          radius: 70,
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 35,
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