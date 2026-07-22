// lib/features/fuel/presentation/widgets/analytics/reconciliation_view.dart

import 'dart:convert';
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
  String _period = 'All';
  DateTime? _customFrom;
  DateTime? _customTo;

  bool _loadingReconciliation = true;
  List<FuelDayReconciliation> _reconciliation = [];
  String? _selectedFuelType;

  bool _loadingPumps = true;
  List<_PumpDayRecord> _pumpRecords = [];

  bool _loadingMeterContinuity = true;
  List<MeterContinuityIssue> _meterContinuityIssues = [];

  bool _loadingTankDipVariance = true;
  List<TankDipVariance> _tankDipVariances = [];

  // Tank table sort
  String _tankSort = 'Date'; // 'Date' | 'Gap' | 'Status'
  // Pump table sort
  bool _sortByPump = true;

  final money = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, String?> _computeDateRange() {
    final now = DateTime.now();
    String fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
    switch (_period) {
      case 'Today': return {'from': fmt(now), 'to': fmt(now)};
      case 'Week':
        return {'from': fmt(now.subtract(Duration(days: now.weekday - 1))), 'to': fmt(now)};
      case 'Month':
        return {'from': fmt(DateTime(now.year, now.month, 1)), 'to': fmt(now)};
      case 'Year':
        return {'from': fmt(DateTime(now.year, 1, 1)), 'to': fmt(now)};
      case 'Custom':
        if (_customFrom == null || _customTo == null) return {'from': null, 'to': null};
        return {'from': fmt(_customFrom!), 'to': fmt(_customTo!)};
      default: return {'from': null, 'to': null};
    }
  }

  Future<void> _load() async {
    setState(() {
      _loadingReconciliation = true;
      _loadingPumps = true;
      _loadingMeterContinuity = true;
      _loadingTankDipVariance = true;
    });
    final range = _computeDateRange();
    final recon = await Services.reconciliation.computeAll(fromDate: range['from'], toDate: range['to']);
    final pumps = await _fetchPumpRecords(range['from'], range['to']);
    final meterIssues = await Services.reconciliation.checkMeterContinuity(fromDate: range['from'], toDate: range['to']);
    final dipVariances = await Services.reconciliation.checkTankDipVariance(fromDate: range['from'], toDate: range['to']);
    if (!mounted) return;
    setState(() {
      _reconciliation = recon;
      _loadingReconciliation = false;
      if (recon.isNotEmpty && (_selectedFuelType == null || !recon.any((r) => r.fuelType == _selectedFuelType))) {
        _selectedFuelType = recon.first.fuelType;
      }
      _pumpRecords = _computeMeterGaps(pumps);
      _loadingPumps = false;
      _meterContinuityIssues = meterIssues;
      _loadingMeterContinuity = false;
      _tankDipVariances = dipVariances;
      _loadingTankDipVariance = false;
    });
  }

  Future<List<_PumpDayRecord>> _fetchPumpRecords(String? fromDate, String? toDate) async {
    final records = await Services.analytics.fetchRawOutbox(fromDate: fromDate, toDate: toDate);
    final result = <_PumpDayRecord>[];
    for (final r in records) {
      final payload = jsonDecode(r['payloadJson'] as String) as Map<String, dynamic>;
      final date = r['businessDate'] as String;
      final sales = (payload['sales'] as List? ?? []);
      for (final s in sales) {
        final pump = (s['pumpNo'] as String?) ?? 'Unknown';
        if (pump == 'Imported' || pump == 'Unknown') continue;
        result.add(_PumpDayRecord(
          businessDate: date,
          pumpNo: pump,
          fuelType: (s['fuelType'] as String?) ?? '',
          opening: (s['opening'] as num?)?.toDouble() ?? 0.0,
          closing: (s['closing'] as num?)?.toDouble() ?? 0.0,
          liters: (s['liters'] as num?)?.toDouble() ?? 0.0,
          unitPrice: (s['unitPrice'] as num?)?.toDouble() ?? 0.0,
          amount: (s['totalAmount'] as num?)?.toDouble() ?? 0.0,
          meterGap: 0.0,
          hasMeterGap: false,
        ));
      }
    }
    return result;
  }

  /// Compute meter gaps: today's closing should equal tomorrow's opening
  /// for the same pump+fuel combination.
  List<_PumpDayRecord> _computeMeterGaps(List<_PumpDayRecord> records) {
    // Group by pump+fuel
    final Map<String, List<_PumpDayRecord>> grouped = {};
    for (final r in records) {
      final key = '${r.pumpNo}-${r.fuelType}';
      grouped.putIfAbsent(key, () => []).add(r);
    }

    final result = <_PumpDayRecord>[];
    for (final group in grouped.values) {
      group.sort((a, b) => a.businessDate.compareTo(b.businessDate));
      for (int i = 0; i < group.length; i++) {
        final r = group[i];
        double meterGap = 0.0;
        bool hasMeterGap = false;

        if (i + 1 < group.length) {
          // Check if this day's closing matches next day's opening
          final nextOpening = group[i + 1].opening;
          if (r.closing > 0 && nextOpening > 0) {
            meterGap = nextOpening - r.closing;
            hasMeterGap = meterGap.abs() > 1;
          }
        }

        result.add(_PumpDayRecord(
          businessDate: r.businessDate,
          pumpNo: r.pumpNo,
          fuelType: r.fuelType,
          opening: r.opening,
          closing: r.closing,
          liters: r.liters,
          unitPrice: r.unitPrice,
          amount: r.amount,
          meterGap: meterGap,
          hasMeterGap: hasMeterGap,
        ));
      }
    }

    return result;
  }

  List<FuelDayReconciliation> get _filtered =>
      _reconciliation.where((r) => r.fuelType == _selectedFuelType).toList();

  List<FuelDayReconciliation> get _sortedFiltered {
    final list = [..._filtered];
    switch (_tankSort) {
      case 'Gap':
        list.sort((a, b) => a.gap.compareTo(b.gap)); // worst first
        break;
      case 'Status':
        list.sort((a, b) => _statusOrder(a).compareTo(_statusOrder(b)));
        break;
      default:
        list.sort((a, b) => a.businessDate.compareTo(b.businessDate));
    }
    return list;
  }

  int _statusOrder(FuelDayReconciliation r) {
    if (!r.hasBaseline) return 5;
    final abs = r.gap.abs();
    if (abs == 0) return 4;
    if (abs <= 500) return 3;
    if (abs <= 2000) return 2;
    if (abs <= 5000) return 1;
    return 0; // Critical first
  }

  List<_PumpDayRecord> get _sortedPumps {
    final list = [..._pumpRecords];
    if (_sortByPump) {
      list.sort((a, b) {
        final pa = int.tryParse(a.pumpNo) ?? 999;
        final pb = int.tryParse(b.pumpNo) ?? 999;
        final pc = pa.compareTo(pb);
        if (pc != 0) return pc;
        return a.businessDate.compareTo(b.businessDate);
      });
    } else {
      list.sort((a, b) {
        final dc = a.businessDate.compareTo(b.businessDate);
        if (dc != 0) return dc;
        final pa = int.tryParse(a.pumpNo) ?? 999;
        final pb = int.tryParse(b.pumpNo) ?? 999;
        return pa.compareTo(pb);
      });
    }
    return list;
  }

  List<String> get _fuelTypes =>
      _reconciliation.map((r) => r.fuelType).toSet().toList()..sort();

  String _gapStatus(FuelDayReconciliation r) {
    if (!r.hasBaseline) return 'No Baseline';
    final abs = r.gap.abs();
    if (abs == 0) return 'Balanced';
    if (abs <= 500) return 'Normal';
    if (abs <= 2000) return 'Investigate';
    if (abs <= 5000) return 'High Risk';
    return 'Critical';
  }

  Color _gapStatusColor(FuelDayReconciliation r) {
    if (!r.hasBaseline) return textSecondary;
    final abs = r.gap.abs();
    if (abs == 0) return Colors.greenAccent;
    if (abs <= 500) return Colors.green;
    if (abs <= 2000) return Colors.orange;
    if (abs <= 5000) return Colors.redAccent;
    return Colors.red;
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
          if (_loadingReconciliation)
            const Center(child: CircularProgressIndicator())
          else if (_reconciliation.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Not enough sent days yet.\nReconciliation needs at least 2 sent business dates.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary),
                ),
              ),
            )
          else ...[
            // Row 1: Tank LEFT, Pump RIGHT
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: _buildTankSection()),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: _buildPumpSection()),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Row 2: Shortage Analysis full width
            _buildShortageAnalysis(),
            const SizedBox(height: 20),

            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: _buildTankSection()),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: _buildPumpSection()),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildShortageAnalysis(),
            const SizedBox(height: 20),
            _buildMeterContinuitySection(),
            const SizedBox(height: 20),
            _buildTankDipVarianceSection(),
            const SizedBox(height: 20),
            if (_filtered.isNotEmpty) _buildReconciliationInsights(_filtered),
            // Row 3: Reconciliation Insights full width
            if (_filtered.isNotEmpty) _buildReconciliationInsights(_filtered),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Wrap(
      spacing: 8,
      children: [
        ...['Today', 'Week', 'Month', 'Year', 'All', 'Custom'].map((p) =>
            pillButton(p, _period == p, () { setState(() => _period = p); _load(); })),
        if (_period == 'Custom') ...[
          TextButton(
            onPressed: () async {
              final picked = await showThemedDatePicker(context, initial: _customFrom);
              if (picked != null) { setState(() => _customFrom = picked); if (_customTo != null) _load(); }
            },
            child: Text(_customFrom == null ? 'From' : DateFormat('MMM d, yyyy').format(_customFrom!),
                style: const TextStyle(color: textSecondary)),
          ),
          const Text('→', style: TextStyle(color: textSecondary)),
          TextButton(
            onPressed: () async {
              final picked = await showThemedDatePicker(context, initial: _customTo);
              if (picked != null) { setState(() => _customTo = picked); if (_customFrom != null) _load(); }
            },
            child: Text(_customTo == null ? 'To' : DateFormat('MMM d, yyyy').format(_customTo!),
                style: const TextStyle(color: textSecondary)),
          ),
        ],
      ],
    );
  }

  // ── TANK SECTION ──────────────────────────────────────────────────
  Widget _buildTankSection() {
    final data = _sortedFiltered;
    final totalMissing = data.where((r) => r.gap < 0).fold(0.0, (s, r) => s + r.gap.abs());
    final criticalDays = data.where((r) => r.gap.abs() > 5000).length;
    final unusualDays = data.where((r) => r.isUnusual).length;

    return Container(
      decoration: BoxDecoration(
        color: panelBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: panelBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fuel selector + sort
          Row(
            children: [
              DropdownButton<String>(
                value: _selectedFuelType,
                dropdownColor: panelBg2,
                style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
                underline: const SizedBox.shrink(),
                items: _fuelTypes.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (v) => setState(() => _selectedFuelType = v),
              ),
              const Text(' — Tank Reconciliation',
                  style: TextStyle(color: textSecondary, fontSize: 12)),
              const Spacer(),
              // Sort toggle
              ...[('Date', 'Date'), ('Gap', 'Gap ↑'), ('Status', 'Status')].map((s) =>
                GestureDetector(
                  onTap: () => setState(() => _tankSort = s.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: _tankSort == s.$1 ? Colors.orange.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _tankSort == s.$1 ? Colors.orange : panelBorder),
                    ),
                    child: Text(s.$2, style: TextStyle(
                      color: _tankSort == s.$1 ? Colors.orange : textSecondary,
                      fontSize: 10, fontWeight: FontWeight.w600,
                    )),
                  ),
                )),
            ],
          ),
          const SizedBox(height: 10),
          // Tiny KPI row
          Row(
            children: [
              _tinyCard('Missing', '${totalMissing.toStringAsFixed(0)} L',
                  totalMissing > 0 ? Colors.redAccent : Colors.greenAccent),
              const SizedBox(width: 8),
              _tinyCard('Critical', '$criticalDays days', criticalDays > 0 ? Colors.red : Colors.greenAccent),
              const SizedBox(width: 8),
              _tinyCard('Unusual', '$unusualDays flagged', unusualDays > 0 ? Colors.orange : Colors.greenAccent),
            ],
          ),
          const SizedBox(height: 12),
          // Table
          _buildTankTable(data),
        ],
      ),
    );
  }

  Widget _tinyCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: textSecondary, fontSize: 9)),
            Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildTankTable(List<FuelDayReconciliation> data) {
    final headers = ['Date', 'Start', 'Delivered', 'Sold', 'Expected', 'Actual', 'Gap', 'Status'];
    final widths = [94.0, 68.0, 80.0, 60.0, 80.0, 68.0, 64.0, 82.0];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(headers.length, (i) =>
              SizedBox(width: widths[i],
                child: Text(headers[i], style: const TextStyle(color: textSecondary, fontWeight: FontWeight.w600, fontSize: 11)))),
          ),
          const Divider(color: panelBorder, height: 10),
          SizedBox(
            height: 15 * 34.0,
            child: SingleChildScrollView(
              child: Column(
                children: data.map((r) {
                  final gapColor = !r.hasBaseline ? textSecondary
                      : r.gap < -5 ? (r.isUnusual ? Colors.redAccent : Colors.orange)
                      : Colors.greenAccent;
                  final statusColor = _gapStatusColor(r);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      SizedBox(width: 94, child: Text(r.businessDate, style: const TextStyle(color: textPrimary, fontSize: 11))),
                      SizedBox(width: 68, child: Text(r.startLevel.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 11))),
                      SizedBox(width: 80, child: Text(r.delivered.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 11))),
                      SizedBox(width: 60, child: Text(r.sold.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 11))),
                      SizedBox(width: 80, child: Text(r.expectedEnd.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 11))),
                      SizedBox(width: 68, child: Text(r.actualEnd.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 11))),
                      SizedBox(width: 64, child: Text('${r.gap >= 0 ? '+' : ''}${r.gap.toStringAsFixed(0)}',
                          style: TextStyle(color: gapColor, fontSize: 11, fontWeight: FontWeight.w700))),
                      SizedBox(width: 82, child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(_gapStatus(r), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w700)),
                      )),
                    ]),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PUMP SECTION ──────────────────────────────────────────────────
  Widget _buildPumpSection() {
    if (_loadingPumps) {
      return Container(
        decoration: BoxDecoration(color: panelBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: panelBorder)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final sorted = _sortedPumps;
    if (sorted.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: panelBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: panelBorder)),
        child: const Center(child: Text(
          'No pump meter readings for this period.\nRequires opening & closing readings per pump.',
          textAlign: TextAlign.center, style: TextStyle(color: textSecondary),
        )),
      );
    }

    final totalLiters = sorted.fold(0.0, (s, r) => s + r.liters);
    final totalRevenue = sorted.fold(0.0, (s, r) => s + r.amount);
    final gapCount = sorted.where((r) => r.hasMeterGap).length;

    final headers = ['Date', 'Pump', 'Fuel', 'Opening', 'Closing', 'Sold (L)', '₦/L', 'Amount', 'Next-Day Gap'];
    final widths = [94.0, 64.0, 48.0, 76.0, 76.0, 64.0, 60.0, 100.0, 92.0];

    return Container(
      decoration: BoxDecoration(
        color: panelBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: panelBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Pump Reconciliation',
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _sortByPump = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _sortByPump ? Colors.orange.withOpacity(0.15) : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                    border: Border.all(color: _sortByPump ? Colors.orange : panelBorder),
                  ),
                  child: Text('By Pump', style: TextStyle(color: _sortByPump ? Colors.orange : textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _sortByPump = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: !_sortByPump ? Colors.orange.withOpacity(0.15) : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                    border: Border.all(color: !_sortByPump ? Colors.orange : panelBorder),
                  ),
                  child: Text('By Date', style: TextStyle(color: !_sortByPump ? Colors.orange : textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Tiny KPI row
          Row(
            children: [
              _tinyCard('Total Sold', '${totalLiters.toStringAsFixed(0)} L', Colors.green),
              const SizedBox(width: 8),
              _tinyCard('Revenue', moneyFmt.format(totalRevenue), Colors.cyan),
              const SizedBox(width: 8),
              _tinyCard('Meter Gaps', '$gapCount days', gapCount > 0 ? Colors.orange : Colors.greenAccent),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: List.generate(headers.length, (i) =>
                  SizedBox(width: widths[i],
                    child: Text(headers[i], style: const TextStyle(color: textSecondary, fontWeight: FontWeight.w600, fontSize: 11))))),
                const Divider(color: panelBorder, height: 10),
                SizedBox(
                  height: 15 * 34.0,
                  child: SingleChildScrollView(
                    child: Column(
                      children: sorted.map((r) {
                        final gapColor = !r.hasMeterGap ? Colors.greenAccent
                            : r.meterGap.abs() < 50 ? Colors.orange : Colors.redAccent;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            SizedBox(width: 94, child: Text(r.businessDate, style: const TextStyle(color: textPrimary, fontSize: 11))),
                            SizedBox(width: 64, child: Text('Pump ${r.pumpNo}', style: const TextStyle(color: textPrimary, fontSize: 11))),
                            SizedBox(width: 48, child: Text(r.fuelType, style: const TextStyle(color: textSecondary, fontSize: 11))),
                            SizedBox(width: 76, child: Text(r.opening.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 11))),
                            SizedBox(width: 76, child: Text(r.closing.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 11))),
                            SizedBox(width: 64, child: Text(r.liters.toStringAsFixed(0),
                                style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600))),
                            SizedBox(width: 60, child: Text(r.unitPrice.toStringAsFixed(0), style: const TextStyle(color: textSecondary, fontSize: 11))),
                            SizedBox(width: 100, child: Text(moneyFmt.format(r.amount),
                                style: const TextStyle(color: textPrimary, fontSize: 11, fontWeight: FontWeight.w600))),
                            SizedBox(width: 92, child: r.hasMeterGap
                                ? Row(children: [
                                    Icon(Icons.warning_amber_rounded, color: gapColor, size: 12),
                                    const SizedBox(width: 4),
                                    Text('${r.meterGap >= 0 ? '+' : ''}${r.meterGap.toStringAsFixed(0)} L',
                                        style: TextStyle(color: gapColor, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ])
                                : const Text('—', style: TextStyle(color: textSecondary, fontSize: 11))),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── SHORTAGE ANALYSIS (tank vs pump per fuel type + per day) ──────
  Widget _buildShortageAnalysis() {
    // Per fuel type: tank consumed vs pump sold
    final Map<String, double> tankSoldByFuel = {};
    for (final r in _reconciliation) {
      tankSoldByFuel[r.fuelType] = (tankSoldByFuel[r.fuelType] ?? 0.0) + r.sold;
    }

    final Map<String, double> pumpSoldByFuel = {};
    final Map<String, double> pumpRevenueByFuel = {};
    for (final r in _pumpRecords) {
      pumpSoldByFuel[r.fuelType] = (pumpSoldByFuel[r.fuelType] ?? 0.0) + r.liters;
      pumpRevenueByFuel[r.fuelType] = (pumpRevenueByFuel[r.fuelType] ?? 0.0) + r.amount;
    }

    final allFuels = {...tankSoldByFuel.keys, ...pumpSoldByFuel.keys}.toList()..sort();

    // Per day: tank gap vs pump meter gap
    final Map<String, double> tankGapByDay = {};
    for (final r in _filtered) {
      tankGapByDay[r.businessDate] = (tankGapByDay[r.businessDate] ?? 0.0) + r.gap;
    }
    final Map<String, double> pumpMeterGapByDay = {};
    for (final r in _pumpRecords) {
      if (r.hasMeterGap) {
        pumpMeterGapByDay[r.businessDate] =
            (pumpMeterGapByDay[r.businessDate] ?? 0.0) + r.meterGap;
      }
    }
    final allDays = {...tankGapByDay.keys, ...pumpMeterGapByDay.keys}.toList()..sort();

    return Container(
      decoration: BoxDecoration(
        color: panelBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: panelBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Shortage Analysis — Tank vs Pump',
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          const Text(
            'Compares what the tank lost vs what pumps recorded selling. '
            'A discrepancy between the two suggests unrecorded losses, meter errors, or theft.',
            style: TextStyle(color: textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 16),

          // Per fuel type summary
          const Text('By Fuel Type', style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(120),
              columnWidths: const {0: FixedColumnWidth(80), 1: FixedColumnWidth(120), 2: FixedColumnWidth(120), 3: FixedColumnWidth(120), 4: FixedColumnWidth(140)},
              children: [
                TableRow(children: ['Fuel', 'Tank Consumed', 'Pump Sold', 'Variance (L)', 'Pump Revenue']
                    .map((h) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(h, style: const TextStyle(color: textSecondary, fontWeight: FontWeight.w600, fontSize: 11)),
                    )).toList()),
                ...allFuels.map((fuel) {
                  final tankSold = tankSoldByFuel[fuel] ?? 0.0;
                  final pumpSold = pumpSoldByFuel[fuel] ?? 0.0;
                  final variance = tankSold - pumpSold;
                  final varColor = variance.abs() < 50 ? Colors.greenAccent
                      : variance.abs() < 500 ? Colors.orange : Colors.redAccent;
                  return TableRow(children: [
                    Padding(padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(fuel, style: const TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
                    Text(tankSold.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 12)),
                    Text(pumpSold.toStringAsFixed(0), style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('${variance >= 0 ? '+' : ''}${variance.toStringAsFixed(0)} L',
                        style: TextStyle(color: varColor, fontSize: 12, fontWeight: FontWeight.w700)),
                    Text(moneyFmt.format(pumpRevenueByFuel[fuel] ?? 0.0),
                        style: const TextStyle(color: textPrimary, fontSize: 12)),
                  ]);
                }),
              ],
            ),
          ),

          if (allDays.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('By Day — Tank Gap vs Pump Meter Gap',
                style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 8),
            SizedBox(
              height: 10 * 34.0,
              child: SingleChildScrollView(
                child: Table(
                  columnWidths: const {0: FixedColumnWidth(100), 1: FixedColumnWidth(120), 2: FixedColumnWidth(140), 3: FixedColumnWidth(200)},
                  children: [
                    TableRow(children: ['Date', 'Tank Gap (L)', 'Pump Meter Gap (L)', 'Interpretation']
                        .map((h) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(h, style: const TextStyle(color: textSecondary, fontWeight: FontWeight.w600, fontSize: 11)),
                        )).toList()),
                    ...allDays.map((day) {
                      final tankGap = tankGapByDay[day] ?? 0.0;
                      final pumpGap = pumpMeterGapByDay[day] ?? 0.0;
                      final tankColor = tankGap >= 0 ? Colors.greenAccent : Colors.redAccent;
                      final pumpColor = pumpGap.abs() < 1 ? Colors.greenAccent
                          : pumpGap.abs() < 50 ? Colors.orange : Colors.redAccent;

                      String interpretation = '';
                      if (tankGap < -500 && pumpGap.abs() < 10) interpretation = 'Tank lost fuel, pumps look fine — check delivery';
                      else if (tankGap < -500 && pumpGap.abs() > 50) interpretation = 'Both show losses — investigate pumps & tank';
                      else if (tankGap >= 0 && pumpGap.abs() > 50) interpretation = 'Tank OK but pump meter gap — entry error?';
                      else if (tankGap.abs() < 100 && pumpGap.abs() < 10) interpretation = 'All normal';
                      else interpretation = 'Minor variance — monitor';

                      return TableRow(children: [
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(day, style: const TextStyle(color: textPrimary, fontSize: 11))),
                        Text('${tankGap >= 0 ? '+' : ''}${tankGap.toStringAsFixed(0)}',
                            style: TextStyle(color: tankColor, fontSize: 11, fontWeight: FontWeight.w600)),
                        pumpGap.abs() < 1
                            ? const Text('—', style: TextStyle(color: textSecondary, fontSize: 11))
                            : Text('${pumpGap >= 0 ? '+' : ''}${pumpGap.toStringAsFixed(0)}',
                                style: TextStyle(color: pumpColor, fontSize: 11, fontWeight: FontWeight.w600)),
                        Text(interpretation, style: const TextStyle(color: textSecondary, fontSize: 10)),
                      ]);
                    }),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMeterContinuitySection() {
    if (_loadingMeterContinuity) {
      return Container(
        decoration: BoxDecoration(color: panelBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: panelBorder)),
        padding: const EdgeInsets.all(20),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      decoration: BoxDecoration(color: panelBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: panelBorder)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Meter Continuity', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: (_meterContinuityIssues.isEmpty ? Colors.greenAccent : Colors.redAccent).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _meterContinuityIssues.isEmpty ? 'Clean' : '${_meterContinuityIssues.length} issue(s)',
                style: TextStyle(
                  color: _meterContinuityIssues.isEmpty ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 9, fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          const Text(
            "Checks that each pump's opening reading matches the previous business date's closing reading. A mismatch may indicate a missed reading, meter reset, or tampering.",
            style: TextStyle(color: textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 12),
          if (_meterContinuityIssues.isEmpty)
            const Text('No continuity issues found for this period.', style: TextStyle(color: textSecondary, fontSize: 12))
          else
            Column(
              children: _meterContinuityIssues.map((issue) {
                final gapColor = issue.gap.abs() > 50 ? Colors.redAccent : Colors.orange;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: gapColor, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pump ${issue.pumpNo}: closed at ${issue.previousClosing.toStringAsFixed(0)} on ${issue.previousDate}, '
                          'opened at ${issue.currentOpening.toStringAsFixed(0)} on ${issue.currentDate} '
                          '(${issue.gap >= 0 ? '+' : ''}${issue.gap.toStringAsFixed(0)}L)',
                          style: TextStyle(color: gapColor, fontSize: 12),
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

  Widget _buildTankDipVarianceSection() {
    if (_loadingTankDipVariance) {
      return Container(
        decoration: BoxDecoration(color: panelBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: panelBorder)),
        padding: const EdgeInsets.all(20),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final significant = _tankDipVariances.where((v) => v.isSignificant).toList();
    final sorted = [..._tankDipVariances]..sort((a, b) => b.businessDate.compareTo(a.businessDate));

    return Container(
      decoration: BoxDecoration(color: panelBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: panelBorder)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Tank Dip vs System Level', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: (significant.isEmpty ? Colors.greenAccent : Colors.redAccent).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                significant.isEmpty ? 'Clean' : '${significant.length} flagged',
                style: TextStyle(
                  color: significant.isEmpty ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 9, fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          const Text(
            'Cross-checks physically-measured Tank Dip readings against the recorded system tank level for the same day — an independent check that can catch losses a sales/delivery calculation alone would miss.',
            style: TextStyle(color: textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            const Text('No Tank Dip readings recorded for this period.', style: TextStyle(color: textSecondary, fontSize: 12))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                columnWidths: const {0: FixedColumnWidth(100), 1: FixedColumnWidth(70), 2: FixedColumnWidth(100), 3: FixedColumnWidth(100), 4: FixedColumnWidth(90)},
                children: [
                  TableRow(children: ['Date', 'Fuel', 'Dip Reading', 'System Level', 'Variance']
                      .map((h) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(h, style: const TextStyle(color: textSecondary, fontWeight: FontWeight.w600, fontSize: 11)),
                          ))
                      .toList()),
                  ...sorted.map((v) {
                    final color = v.isSignificant ? Colors.redAccent : Colors.greenAccent;
                    return TableRow(children: [
                      Padding(padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(v.businessDate, style: const TextStyle(color: textPrimary, fontSize: 11))),
                      Text(v.fuelType, style: const TextStyle(color: textPrimary, fontSize: 11)),
                      Text(v.dipReading.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 11)),
                      Text(v.systemLevel.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 11)),
                      Text('${v.variance >= 0 ? '+' : ''}${v.variance.toStringAsFixed(0)} L',
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                    ]);
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── RECONCILIATION INSIGHTS ───────────────────────────────────────
  Widget _buildReconciliationInsights(List<FuelDayReconciliation> data) {
    final insights = <_ReconciliationInsight>[];
    final fuel = _selectedFuelType ?? '';
    final lossDays = data.where((r) => r.gap < 0).toList();
    final unusualDays = data.where((r) => r.isUnusual).toList();
    final totalLoss = lossDays.fold(0.0, (s, r) => s + r.gap.abs());
    final totalDays = data.length;
    final lossRate = totalDays > 0 ? (lossDays.length / totalDays * 100).round() : 0;

    if (lossRate >= 50) insights.add(_ReconciliationInsight(isWarning: true,
        title: '$fuel losses on $lossRate% of days',
        detail: '${lossDays.length} of $totalDays days had negative gaps — consistent pattern, not random.'));
    if (unusualDays.length >= 2) insights.add(_ReconciliationInsight(isWarning: true,
        title: '${unusualDays.length} unusual days for $fuel',
        detail: 'Check: ${unusualDays.map((r) => r.businessDate).join(', ')}.'));
    final worstDay = lossDays.isEmpty ? null : lossDays.reduce((a, b) => a.gap < b.gap ? a : b);
    if (worstDay != null && worstDay.gap.abs() > 5000) insights.add(_ReconciliationInsight(isWarning: true,
        title: 'Critical loss on ${worstDay.businessDate}',
        detail: '${worstDay.gap.abs().toStringAsFixed(0)}L unaccounted. Check delivery records and meter readings.'));
    else if (worstDay != null && worstDay.gap.abs() > 500) insights.add(_ReconciliationInsight(isWarning: true,
        title: 'Large loss on ${worstDay.businessDate}',
        detail: '${worstDay.gap.abs().toStringAsFixed(0)}L unaccounted. Investigate meter calibration.'));
    if (lossDays.length >= 3 && unusualDays.isEmpty && totalLoss > 100) insights.add(_ReconciliationInsight(
        isWarning: false, title: 'Consistent small losses for $fuel',
        detail: '${totalLoss.toStringAsFixed(0)}L total across ${lossDays.length} days — cumulative loss warrants attention.'));

    final pumpGapDays = _pumpRecords.where((r) => r.hasMeterGap).length;
    if (pumpGapDays > 0) insights.add(_ReconciliationInsight(isWarning: true,
        title: '$pumpGapDays pump meter gap(s) detected',
        detail: 'Today\'s closing meter doesn\'t match next day\'s opening for $pumpGapDays record(s). Check meter readings.'));

    if (insights.isEmpty && totalLoss < 50) insights.add(_ReconciliationInsight(
        isWarning: false, isPositive: true, title: '$fuel reconciliation looks clean',
        detail: 'No significant losses. Total unaccounted: ${totalLoss.toStringAsFixed(0)}L.'));

    return Container(
      decoration: BoxDecoration(color: panelBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: panelBorder)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
            const SizedBox(width: 6),
            const Text('Reconciliation Insights',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.4))),
              child: const Text('Rule-based', style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12, runSpacing: 12,
            children: insights.map((insight) {
              final color = insight.isPositive ? Colors.greenAccent
                  : insight.isWarning ? Colors.orange : Colors.cyan;
              final icon = insight.isPositive ? Icons.check_circle_outline
                  : insight.isWarning ? Icons.warning_amber_rounded : Icons.info_outline;
              return Container(
                width: 320,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(insight.title, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(height: 3),
                    Text(insight.detail, style: const TextStyle(color: textSecondary, fontSize: 11)),
                  ])),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PumpDayRecord {
  final String businessDate, pumpNo, fuelType;
  final double opening, closing, liters, unitPrice, amount;
  final double meterGap;
  final bool hasMeterGap;
  _PumpDayRecord({
    required this.businessDate, required this.pumpNo, required this.fuelType,
    required this.opening, required this.closing, required this.liters,
    required this.unitPrice, required this.amount,
    required this.meterGap, required this.hasMeterGap,
  });
}

class _ReconciliationInsight {
  final bool isWarning, isPositive;
  final String title, detail;
  _ReconciliationInsight({required this.isWarning, required this.title, required this.detail, this.isPositive = false});
}