// lib/features/fuel/presentation/widgets/analytics/reconciliation_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/services/reconciliation_service.dart';
import '../../../../../core/services/analytics_service.dart';
import '../../../../../core/services/service_registry.dart';
import 'shared.dart';

class AnalyticsReconciliationView extends StatefulWidget {
  const AnalyticsReconciliationView({super.key});

  @override
  State<AnalyticsReconciliationView> createState() =>
      _AnalyticsReconciliationViewState();
}

class _AnalyticsReconciliationViewState
    extends State<AnalyticsReconciliationView> {
  bool _loadingReconciliation = true;
  List<FuelDayReconciliation> _reconciliation = [];
  String? _selectedFuelType;

  final money =
      NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

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

  List<String> get _fuelTypes =>
      _reconciliation.map((r) => r.fuelType).toSet().toList()..sort();

  List<FuelDayReconciliation> get _filtered =>
      _reconciliation.where((r) => r.fuelType == _selectedFuelType).toList();

  @override
  Widget build(BuildContext context) {
    if (_loadingReconciliation) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reconciliation.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Not enough sent days yet to reconcile tank levels.\n'
            'Reconciliation needs at least 2 sent business dates.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary),
          ),
        ),
      );
    }

    final fuelTypes = _fuelTypes;
    final filtered = _filtered;
    

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Fuel selector ─────────────────────────────────────────
          Row(
            children: [
              const Text('Fuel Type:',
                  style: TextStyle(
                      color: textPrimary, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedFuelType,
                dropdownColor: panelBg2,
                style: const TextStyle(color: textPrimary),
                items: fuelTypes
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedFuelType = v),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.info_outline, size: 14, color: textSecondary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Compare expected vs actual tank levels per day. '
                  'A negative gap means fuel is unaccounted for.',
                  style: TextStyle(color: textSecondary, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Row: Gap Table (left) + AI Insights (right) ──────────────
          if (filtered.isNotEmpty)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // LEFT: Raw gap table
                  Expanded(
                    flex: 3,
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
                          Text(
                            '$_selectedFuelType — Day-by-Day Reconciliation',
                            style: const TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          _buildGapTable(filtered),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // RIGHT: Reconciliation Insights
                  Expanded(
                    flex: 2,
                    child: _buildReconciliationInsights(filtered),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // ── Shortage Analysis full width below ────────────────────────
          if (filtered.isNotEmpty) _buildShortageAnalysis(filtered),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGapTable(List<FuelDayReconciliation> data) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(100),
        columnWidths: const {
          0: FixedColumnWidth(100),
          1: FixedColumnWidth(90),
          2: FixedColumnWidth(90),
          3: FixedColumnWidth(90),
          4: FixedColumnWidth(90),
          5: FixedColumnWidth(90),
          6: FixedColumnWidth(90),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: panelBorder.withOpacity(0.5), width: 1)),
            ),
            children: ['Date', 'Start', 'Delivered', 'Sold', 'Expected', 'Actual', 'Gap']
                .map((h) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(h,
                          style: const TextStyle(
                              color: textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11)),
                    ))
                .toList(),
          ),
          ...data.map((r) {
            final gapColor = !r.hasBaseline
                ? textSecondary
                : r.isUnusual
                    ? Colors.redAccent
                    : r.gap < -5
                        ? Colors.orange
                        : Colors.greenAccent;

            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(r.businessDate,
                      style: const TextStyle(color: textPrimary, fontSize: 11)),
                ),
                Text(r.startLevel.toStringAsFixed(0),
                    style: const TextStyle(color: textPrimary, fontSize: 11)),
                Text(r.delivered.toStringAsFixed(0),
                    style: const TextStyle(color: textPrimary, fontSize: 11)),
                Text(r.sold.toStringAsFixed(0),
                    style: const TextStyle(color: textPrimary, fontSize: 11)),
                Text(r.expectedEnd.toStringAsFixed(0),
                    style: const TextStyle(color: textPrimary, fontSize: 11)),
                Text(r.actualEnd.toStringAsFixed(0),
                    style: const TextStyle(color: textPrimary, fontSize: 11)),
                Text(
                  '${r.gap >= 0 ? '+' : ''}${r.gap.toStringAsFixed(0)}'
                  '${r.isUnusual ? ' ⚠' : ''}',
                  style: TextStyle(
                      color: gapColor, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildShortageAnalysis(List<FuelDayReconciliation> data) {
    final lossDays = data.where((r) => r.gap < 0).toList();
    final unusualDays = data.where((r) => r.isUnusual).toList();
    final totalLoss = lossDays.fold(0.0, (s, r) => s + r.gap.abs());
    final netGap = data.fold(0.0, (s, r) => s + r.gap);
    final totalDays = data.length;

    // Sort worst days
    final worstDays = [...lossDays]..sort((a, b) => a.gap.compareTo(b.gap));

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
          const Text('Shortage Analysis',
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'Total Unaccounted',
                  '${totalLoss.toStringAsFixed(0)} L',
                  totalLoss > 0 ? Colors.redAccent : Colors.greenAccent,
                  subtitle: '${lossDays.length} of $totalDays day(s) with losses',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'Unusual Days',
                  '${unusualDays.length}',
                  unusualDays.isNotEmpty ? Colors.redAccent : Colors.greenAccent,
                  subtitle: unusualDays.isNotEmpty ? 'statistically flagged' : 'none flagged',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'Net Gap',
                  '${netGap >= 0 ? '+' : ''}${netGap.toStringAsFixed(0)} L',
                  netGap >= 0 ? Colors.greenAccent : Colors.redAccent,
                  subtitle: netGap >= 0 ? 'net surplus' : 'net deficit',
                ),
              ),
            ],
          ),
          if (worstDays.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Worst loss days:',
                style: TextStyle(color: textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            ...worstDays.take(3).map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_downward,
                          color: Colors.redAccent, size: 14),
                      const SizedBox(width: 8),
                      Text(r.businessDate,
                          style: const TextStyle(color: textPrimary, fontSize: 12)),
                      const Spacer(),
                      Text(
                        '${r.gap.toStringAsFixed(0)} L'
                        '${r.isUnusual ? '  ⚠ unusual' : ''}',
                        style: TextStyle(
                          color: r.isUnusual ? Colors.redAccent : Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildReconciliationInsights(List<FuelDayReconciliation> data) {
    final insights = <_ReconciliationInsight>[];
    final fuel = _selectedFuelType ?? '';
    final lossDays = data.where((r) => r.gap < 0).toList();
    final unusualDays = data.where((r) => r.isUnusual).toList();
    final totalLoss = lossDays.fold(0.0, (s, r) => s + r.gap.abs());
    final totalDays = data.length;
    final lossRate = totalDays > 0 ? (lossDays.length / totalDays * 100).round() : 0;

    if (lossRate >= 50) {
      insights.add(_ReconciliationInsight(
        isWarning: true,
        title: '$fuel losses on $lossRate% of days',
        detail: '${lossDays.length} out of $totalDays days showed a negative gap. '
            'This suggests a consistent issue, not random variance.',
      ));
    }

    if (unusualDays.length >= 2) {
      insights.add(_ReconciliationInsight(
        isWarning: true,
        title: '${unusualDays.length} statistically unusual days for $fuel',
        detail: 'These days deviate significantly from the normal gap pattern. '
            'Check: ${unusualDays.map((r) => r.businessDate).join(', ')}.',
      ));
    }

    final worstDay = lossDays.isEmpty
        ? null
        : lossDays.reduce((a, b) => a.gap < b.gap ? a : b);
    if (worstDay != null && worstDay.gap.abs() > 500) {
      insights.add(_ReconciliationInsight(
        isWarning: true,
        title: 'Large single-day loss on ${worstDay.businessDate}',
        detail: '${worstDay.gap.abs().toStringAsFixed(0)}L unaccounted on this day alone. '
            'Check if a delivery was recorded correctly or if there was a meter reset.',
      ));
    }

    if (lossDays.length >= 3 && unusualDays.isEmpty && totalLoss > 100) {
      insights.add(_ReconciliationInsight(
        isWarning: false,
        title: 'Consistent small losses for $fuel',
        detail: '${totalLoss.toStringAsFixed(0)}L total across ${lossDays.length} days — '
            'none flagged as unusual individually, but the cumulative loss warrants attention.',
      ));
    }

    if (insights.isEmpty && totalLoss < 50) {
      insights.add(_ReconciliationInsight(
        isWarning: false,
        isPositive: true,
        title: '$fuel reconciliation looks clean',
        detail: 'No significant unexplained losses detected. '
            'Total unaccounted: ${totalLoss.toStringAsFixed(0)}L.',
      ));
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
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              const Text('Reconciliation Insights',
                  style: TextStyle(
                      color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: const Text('Rule-based',
                    style: TextStyle(
                        color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: insights.map((insight) {
              final color = insight.isPositive
                  ? Colors.greenAccent
                  : insight.isWarning
                      ? Colors.orange
                      : Colors.cyan;
              final icon = insight.isPositive
                  ? Icons.check_circle_outline
                  : insight.isWarning
                      ? Icons.warning_amber_rounded
                      : Icons.info_outline;

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
                          Text(insight.title,
                              style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(insight.detail,
                              style: const TextStyle(
                                  color: textSecondary, fontSize: 11)),
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

  Widget _statCard(String label, String value, Color color, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: textSecondary, fontSize: 11)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: textSecondary, fontSize: 10)),
          ],
        ],
      ),
    );
  }
}

class _ReconciliationInsight {
  final bool isWarning;
  final bool isPositive;
  final String title;
  final String detail;

  _ReconciliationInsight({
    required this.isWarning,
    required this.title,
    required this.detail,
    this.isPositive = false,
  });
}