// lib/core/services/reconciliation_service.dart

import 'dart:convert';
import 'dart:math';
import '../../features/fuel/repositories/outbox_repo.dart';
import '../../features/fuel/domain/fuel_mapping.dart';

/// One fuel type's reconciliation result for a single business date.
class FuelDayReconciliation {
  final String businessDate;
  final String fuelType;

  final double startLevel;     // previous day's actual end level
  final double delivered;      // liters delivered this day
  final double sold;           // liters sold this day
  final double expectedEnd;    // startLevel + delivered - sold
  final double actualEnd;      // this day's actual tank snapshot level
  final double gap;            // actualEnd - expectedEnd (negative = missing fuel)

  /// True once enough historical data exists to judge whether this gap
  /// is statistically unusual for this fuel type (needs a few prior
  /// days with their own gaps computed first).
  final bool hasBaseline;

  /// Only meaningful when hasBaseline is true. True if this day's gap
  /// is unusually large relative to this fuel type's own historical
  /// gap pattern (i.e. likely a real anomaly, not just normal noise).
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

class ReconciliationService {
  final OutboxRepo outboxRepo;

  ReconciliationService({required this.outboxRepo});

  /// Computes day-over-day reconciliation for every fuel type, across
  /// all sent business dates, oldest first. The first sent date for
  /// each fuel type has no prior snapshot to compare against, so it's
  /// excluded from the results (nothing to reconcile against).
  Future<List<FuelDayReconciliation>> computeAll({String? fromDate, String? toDate}) async {
  final allRecords = await outboxRepo.fetchAll();
  final records = allRecords.where((r) {
    if (fromDate != null && r.businessDate.compareTo(fromDate) < 0) return false;
    if (toDate != null && r.businessDate.compareTo(toDate) > 0) return false;
    return true;
  }).toList();

    // Sort oldest first by businessDate (not createdAt, since a
    // corrected/backdated send could have a createdAt out of order
    // relative to its true business date).
    final sorted = List.of(records)
      ..sort((a, b) => a.businessDate.compareTo(b.businessDate));

    // Decode once, keep payload alongside each record for easy access.
    final decoded = sorted.map((r) {
      return {
        'businessDate': r.businessDate,
        'payload': jsonDecode(r.payloadJson) as Map<String, dynamic>,
      };
    }).toList();

    // Track each fuel type's most recent actual end level, so the
    // NEXT day's start level is correct.
    final Map<String, double> lastKnownLevel = {};

    // Track each fuel type's gap history, to build a running baseline
    // for "is this gap unusual" judgments.
    final Map<String, List<double>> gapHistory = {};

    final results = <FuelDayReconciliation>[];

    for (final entry in decoded) {
      final businessDate = entry['businessDate'] as String;
      final payload = entry['payload'] as Map<String, dynamic>;

      final sales = (payload['sales'] as List? ?? []);
      final deliveries = (payload['deliveries'] as List? ?? []);
      final tankSnapshot = (payload['tankSnapshot'] as List? ?? []);

      // Sum delivered/sold liters per fuel type for this day.
      final Map<String, double> deliveredByFuel = {};
      for (final d in deliveries) {
        final fuel = FuelMapping.tankKey(d['fuelType'] as String);
        deliveredByFuel[fuel] =
            (deliveredByFuel[fuel] ?? 0.0) + ((d['liters'] as num?)?.toDouble() ?? 0.0);
      }

      final Map<String, double> soldByFuel = {};
      for (final s in sales) {
        final fuel = FuelMapping.tankKey(s['fuelType'] as String);
        soldByFuel[fuel] =
            (soldByFuel[fuel] ?? 0.0) + ((s['liters'] as num?)?.toDouble() ?? 0.0);
      }

      // For each fuel type present in this day's tank snapshot:
      for (final t in tankSnapshot) {
        final fuel = FuelMapping.tankKey(t['fuelType'] as String);
        final actualEnd = (t['currentLevel'] as num).toDouble();

        final startLevel = lastKnownLevel[fuel];

        if (startLevel == null) {
          // First time we've seen this fuel type's snapshot — nothing
          // to reconcile against yet. Just record the level and move on.
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
          final variance = history
                  .map((g) => (g - mean) * (g - mean))
                  .reduce((a, b) => a + b) /
              history.length;
          final stdDev = variance > 0 ? sqrt(variance) : 0.0;

          // Flag as unusual if this gap is more than 2 standard
          // deviations from this fuel type's own historical mean gap,
          // AND the gap itself is non-trivial (avoid flagging tiny
          // gaps on a fuel type with an extremely tight history).
          final deviation = (gap - mean).abs();
          isUnusual = stdDev > 0
              ? (deviation > 2 * stdDev && gap.abs() > 5)
              : (gap.abs() > 5 && deviation > 5);
        }

        history.add(gap);

        results.add(FuelDayReconciliation(
          businessDate: businessDate,
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