// lib/features/fuel/presentation/widgets/analytics/reconciliation_view.dart
//
// The "Reconciliation" tab of the Analytics screen: per-fuel-type
// day-over-day tank gap analysis (candlestick-style bar chart) plus
// the raw numbers table beneath it.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../../core/services/reconciliation_service.dart';
import '../../../../../core/services/service_registry.dart';
import 'shared.dart';

class AnalyticsReconciliationView extends StatefulWidget {
  const AnalyticsReconciliationView({super.key});

  @override
  State<AnalyticsReconciliationView> createState() => _AnalyticsReconciliationViewState();
}

class _AnalyticsReconciliationViewState extends State<AnalyticsReconciliationView> {
  bool _loadingReconciliation = true;
  List<FuelDayReconciliation> _reconciliation = [];
  String? _selectedFuelType;

  @override
  void initState() {
    super.initState();
    _loadReconciliation();
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

  @override
  Widget build(BuildContext context) {
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
}