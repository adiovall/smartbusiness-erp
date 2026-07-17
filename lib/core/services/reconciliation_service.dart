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
}