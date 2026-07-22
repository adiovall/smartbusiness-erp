import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/fuel/domain/fuel_mapping.dart';

class FuelDayReconciliation {
  final String businessDate;
  final String fuelType;
  final double startLevel;
  final double delivered;
  final double sold;
  final double expectedEnd;
  final double actualEnd;
  final double gap;
  final bool hasBaseline;
  final bool isUnusual;

  FuelDayReconciliation({
    required this.businessDate,
    required this.fuelType,
    required this.startLevel,
    required this.delivered,
    required this.sold,
    required this.expectedEnd,
    required this.actualEnd,
    required this.gap,
    required this.hasBaseline,
    required this.isUnusual,
  });
}

class MeterContinuityIssue {
  final String pumpNo;
  final String previousDate;
  final double previousClosing;
  final String currentDate;
  final double currentOpening;

  MeterContinuityIssue({
    required this.pumpNo,
    required this.previousDate,
    required this.previousClosing,
    required this.currentDate,
    required this.currentOpening,
  });

  double get gap => currentOpening - previousClosing;
}

class TankDipVariance {
  final String businessDate;
  final String fuelType;
  final double dipReading;
  final double systemLevel;
  final bool isSignificant;

  TankDipVariance({
    required this.businessDate,
    required this.fuelType,
    required this.dipReading,
    required this.systemLevel,
    required this.isSignificant,
  });

  double get variance => dipReading - systemLevel;
}

/// Reads live from Supabase instead of the local outbox — same public
/// API (computeAll with the same params and return type), so
/// reconciliation_view.dart doesn't need any changes.
class ReconciliationService {
  final SupabaseClient _client = Supabase.instance.client;

  bool _inRange(String date, String? from, String? to) {
    if (from != null && date.compareTo(from) < 0) return false;
    if (to != null && date.compareTo(to) > 0) return false;
    return true;
  }

  Future<List<FuelDayReconciliation>> computeAll({String? fromDate, String? toDate}) async {
    final salesRows = await _client.from('sales').select('business_date, fuel_type, liters');
    final deliveryRows = await _client.from('deliveries').select('business_date, fuel_type, liters');
    final snapshotRows = await _client.from('tank_snapshots').select('business_date, fuel_type, current_level');

    final Map<String, Map<String, double>> deliveredByDateFuel = {};
    for (final d in deliveryRows) {
      final date = d['business_date'] as String;
      if (!_inRange(date, fromDate, toDate)) continue;
      final fuel = FuelMapping.tankKey(d['fuel_type'] as String);
      final liters = (d['liters'] as num?)?.toDouble() ?? 0.0;
      deliveredByDateFuel.putIfAbsent(date, () => {});
      deliveredByDateFuel[date]![fuel] = (deliveredByDateFuel[date]![fuel] ?? 0) + liters;
    }

    final Map<String, Map<String, double>> soldByDateFuel = {};
    for (final s in salesRows) {
      final date = s['business_date'] as String;
      if (!_inRange(date, fromDate, toDate)) continue;
      final fuel = FuelMapping.tankKey(s['fuel_type'] as String);
      final liters = (s['liters'] as num?)?.toDouble() ?? 0.0;
      soldByDateFuel.putIfAbsent(date, () => {});
      soldByDateFuel[date]![fuel] = (soldByDateFuel[date]![fuel] ?? 0) + liters;
    }

    final Map<String, List<Map<String, dynamic>>> snapshotsByDate = {};
    for (final t in snapshotRows) {
      final date = t['business_date'] as String;
      if (!_inRange(date, fromDate, toDate)) continue;
      snapshotsByDate.putIfAbsent(date, () => []).add(t);
    }

    final sortedDates = snapshotsByDate.keys.toList()..sort();

    final Map<String, double> lastKnownLevel = {};
    final Map<String, List<double>> gapHistory = {};
    final results = <FuelDayReconciliation>[];

    for (final date in sortedDates) {
      final snaps = snapshotsByDate[date]!;
      final deliveredByFuel = deliveredByDateFuel[date] ?? {};
      final soldByFuel = soldByDateFuel[date] ?? {};

      for (final t in snaps) {
        final fuel = FuelMapping.tankKey(t['fuel_type'] as String);
        final actualEnd = (t['current_level'] as num).toDouble();

        final startLevel = lastKnownLevel[fuel];
        if (startLevel == null) {
          lastKnownLevel[fuel] = actualEnd;
          continue;
        }

        final delivered = deliveredByFuel[fuel] ?? 0.0;
        final sold = soldByFuel[fuel] ?? 0.0;
        final expectedEnd = startLevel + delivered - sold;
        final gap = actualEnd - expectedEnd;

        final history = gapHistory.putIfAbsent(fuel, () => []);
        bool hasBaseline = history.length >= 3;
        bool isUnusual = false;

        if (hasBaseline) {
          final mean = history.reduce((a, b) => a + b) / history.length;
          final variance = history.map((g) => (g - mean) * (g - mean)).reduce((a, b) => a + b) / history.length;
          final stdDev = variance > 0 ? sqrt(variance) : 0.0;
          final deviation = (gap - mean).abs();
          isUnusual = stdDev > 0 ? (deviation > 2 * stdDev && gap.abs() > 5) : (gap.abs() > 5 && deviation > 5);
        }

        history.add(gap);

        results.add(FuelDayReconciliation(
          businessDate: date,
          fuelType: fuel,
          startLevel: startLevel,
          delivered: delivered,
          sold: sold,
          expectedEnd: expectedEnd,
          actualEnd: actualEnd,
          gap: gap,
          hasBaseline: hasBaseline,
          isUnusual: isUnusual,
        ));

        lastKnownLevel[fuel] = actualEnd;
      }
    }

    return results;
  }

  Future<List<MeterContinuityIssue>> checkMeterContinuity({String? fromDate, String? toDate, double toleranceLiters = 0.5}) async {
    final rows = await _client.from('sales').select('business_date, pump_no, opening, closing');

    final byPump = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      final date = r['business_date'] as String;
      if (!_inRange(date, fromDate, toDate)) continue;
      final pump = (r['pump_no'] as String?) ?? 'Unknown';
      byPump.putIfAbsent(pump, () => []).add(r);
    }

    final issues = <MeterContinuityIssue>[];
    for (final entry in byPump.entries) {
      final sorted = entry.value..sort((a, b) => (a['business_date'] as String).compareTo(b['business_date'] as String));
      for (int i = 1; i < sorted.length; i++) {
        final prev = sorted[i - 1];
        final curr = sorted[i];
        final prevClosing = (prev['closing'] as num).toDouble();
        final currOpening = (curr['opening'] as num).toDouble();

        if ((currOpening - prevClosing).abs() > toleranceLiters) {
          issues.add(MeterContinuityIssue(
            pumpNo: entry.key,
            previousDate: prev['business_date'] as String,
            previousClosing: prevClosing,
            currentDate: curr['business_date'] as String,
            currentOpening: currOpening,
          ));
        }
      }
    }
    return issues;
  }

  Future<List<TankDipVariance>> checkTankDipVariance({String? fromDate, String? toDate, double toleranceLiters = 50}) async {
    final dips = await _client.from('tank_dips').select('business_date, fuel_type, closing_level');
    final snapshots = await _client.from('tank_snapshots').select('business_date, fuel_type, current_level');

    final snapshotByKey = <String, double>{};
    for (final s in snapshots) {
      final key = '${s['business_date']}_${FuelMapping.tankKey(s['fuel_type'] as String)}';
      snapshotByKey[key] = (s['current_level'] as num).toDouble();
    }

    final result = <TankDipVariance>[];
    for (final d in dips) {
      final date = d['business_date'] as String;
      if (!_inRange(date, fromDate, toDate)) continue;
      final fuel = FuelMapping.tankKey(d['fuel_type'] as String);
      final key = '${date}_$fuel';
      final systemLevel = snapshotByKey[key];
      if (systemLevel == null) continue;

      final dipReading = (d['closing_level'] as num).toDouble();
      result.add(TankDipVariance(
        businessDate: date,
        fuelType: fuel,
        dipReading: dipReading,
        systemLevel: systemLevel,
        isSignificant: (dipReading - systemLevel).abs() > toleranceLiters,
      ));
    }
    return result;
  }
}