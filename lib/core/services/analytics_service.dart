// lib/core/services/analytics_service.dart

import 'dart:convert';
import '../../features/fuel/repositories/outbox_repo.dart';

class DayAnalytics {
  final String businessDate;
  final double revenue;
  final double expense;
  final double deliveryCost;
  final double net;

  DayAnalytics({
    required this.businessDate,
    required this.revenue,
    required this.expense,
    required this.deliveryCost,
    required this.net,
  });
}

class FuelPerformance {
  final String fuelType;
  final double revenue;
  final double liters;

  FuelPerformance({
    required this.fuelType,
    required this.revenue,
    required this.liters,
  });
}

/// Aggregated sales performance for ONE pump number, across the
/// selected date range.
class PumpPerformance {
  final String pumpNo;
  final double revenue;
  final double liters;

  PumpPerformance({
    required this.pumpNo,
    required this.revenue,
    required this.liters,
  });
}



class AnalyticsService {
  final OutboxRepo outboxRepo;

  AnalyticsService({required this.outboxRepo});

  Future<List<DayAnalytics>> fetchTrend({String? fromDate, String? toDate}) async {
    final records = await outboxRepo.fetchAll();

    final filtered = records.where((r) {
      if (fromDate != null && r.businessDate.compareTo(fromDate) < 0) return false;
      if (toDate != null && r.businessDate.compareTo(toDate) > 0) return false;
      return true;
    }).toList();

    final list = filtered.map((r) {
      final payload = jsonDecode(r.payloadJson) as Map<String, dynamic>;

      final sales = (payload['sales'] as List? ?? []);
      final expenses = (payload['expenses'] as List? ?? []);
      final deliveries = (payload['deliveries'] as List? ?? []);

      final revenue = sales.fold<double>(
        0.0,
        (sum, s) => sum + ((s['totalAmount'] as num?)?.toDouble() ?? 0.0),
      );
      final expense = expenses.fold<double>(
        0.0,
        (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0),
      );
      final deliveryCost = deliveries.fold<double>(
        0.0,
        (sum, d) => sum + ((d['totalCost'] as num?)?.toDouble() ?? 0.0),
      );

      return DayAnalytics(
        businessDate: r.businessDate,
        revenue: revenue,
        expense: expense,
        deliveryCost: deliveryCost,
        net: revenue - expense,
      );
    }).toList();

    list.sort((a, b) => a.businessDate.compareTo(b.businessDate));
    return list;
  }

  Future<Map<String, dynamic>?> fetchDayDetail(String businessDate) async {
    final record = await outboxRepo.fetchByBusinessDate(businessDate);
    if (record == null) return null;
    return jsonDecode(record.payloadJson) as Map<String, dynamic>;
  }

  Future<List<String>> fetchAvailableDates() async {
    final records = await outboxRepo.fetchAll();
    return records.map((r) => r.businessDate).toList();
  }

  Future<List<FuelPerformance>> fetchFuelPerformance({String? fromDate, String? toDate}) async {
    final records = await outboxRepo.fetchAll();

    final filtered = records.where((r) {
      if (fromDate != null && r.businessDate.compareTo(fromDate) < 0) return false;
      if (toDate != null && r.businessDate.compareTo(toDate) > 0) return false;
      return true;
    }).toList();

    final Map<String, double> revenueByFuel = {};
    final Map<String, double> litersByFuel = {};

    for (final r in filtered) {
      final payload = jsonDecode(r.payloadJson) as Map<String, dynamic>;
      final sales = (payload['sales'] as List? ?? []);

      for (final s in sales) {
        var fuel = s['fuelType'] as String;
        if (fuel == 'LPG') fuel = 'Gas';

        final amount = (s['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final liters = (s['liters'] as num?)?.toDouble() ?? 0.0;

        revenueByFuel[fuel] = (revenueByFuel[fuel] ?? 0.0) + amount;
        litersByFuel[fuel] = (litersByFuel[fuel] ?? 0.0) + liters;
      }
    }

    final result = revenueByFuel.keys.map((fuel) {
      return FuelPerformance(
        fuelType: fuel,
        revenue: revenueByFuel[fuel] ?? 0.0,
        liters: litersByFuel[fuel] ?? 0.0,
      );
    }).toList();

    result.sort((a, b) => b.revenue.compareTo(a.revenue));
    return result;
  }

  Future<List<PumpPerformance>> fetchPumpPerformance({String? fromDate, String? toDate}) async {
    final records = await outboxRepo.fetchAll();

    final filtered = records.where((r) {
      if (fromDate != null && r.businessDate.compareTo(fromDate) < 0) return false;
      if (toDate != null && r.businessDate.compareTo(toDate) > 0) return false;
      return true;
    }).toList();

    final Map<String, double> revenueByPump = {};
    final Map<String, double> litersByPump = {};

    for (final r in filtered) {
      final payload = jsonDecode(r.payloadJson) as Map<String, dynamic>;
      final sales = (payload['sales'] as List? ?? []);

      for (final s in sales) {
        final pump = (s['pumpNo'] as String?) ?? 'Unknown';
        final amount = (s['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final liters = (s['liters'] as num?)?.toDouble() ?? 0.0;

        revenueByPump[pump] = (revenueByPump[pump] ?? 0.0) + amount;
        litersByPump[pump] = (litersByPump[pump] ?? 0.0) + liters;
      }
    }

    final result = revenueByPump.keys.map((pump) {
      return PumpPerformance(
        pumpNo: pump,
        revenue: revenueByPump[pump] ?? 0.0,
        liters: litersByPump[pump] ?? 0.0,
      );
    }).toList();

    // Sort by pump number numerically where possible, so "Pump 1, 2, 3..."
    // doesn't end up as "1, 10, 2, 3..." (string-sort gotcha).
    result.sort((a, b) {
      final aNum = int.tryParse(a.pumpNo);
      final bNum = int.tryParse(b.pumpNo);
      if (aNum != null && bNum != null) return aNum.compareTo(bNum);
      return a.pumpNo.compareTo(b.pumpNo);
    });

    return result;
  }




}