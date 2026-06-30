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

/// Top supplier by total delivery value over the selected period.
class SupplierPerformance {
  final String supplier;
  final double totalDeliveryValue;
  final int deliveryCount;

  SupplierPerformance({
    required this.supplier,
    required this.totalDeliveryValue,
    required this.deliveryCount,
  });
}

/// Expense total per category over the selected period.
class ExpenseCategoryTotal {
  final String category;
  final double amount;

  ExpenseCategoryTotal({required this.category, required this.amount});
}

/// Debt summary per supplier over the selected period.
class DebtSummary {
  final String supplier;
  final String fuelType;
  final double amount;
  final bool settled;

  DebtSummary({
    required this.supplier,
    required this.fuelType,
    required this.amount,
    required this.settled,
  });
}

class ExternalPaymentSummary {
  final String supplier;
  final String fuelType;
  final String kind;
  final double amount;

  ExternalPaymentSummary({
    required this.supplier,
    required this.fuelType,
    required this.kind,
    required this.amount,
  });
}

class CashFlowSummary {
  final double salesRevenue;
  final double expenses;
  final double debtSettlements;
  final double externalPayments;

  CashFlowSummary({
    required this.salesRevenue,
    required this.expenses,
    required this.debtSettlements,
    required this.externalPayments,
  });

  double get netCashFlow => salesRevenue - expenses - debtSettlements - externalPayments;
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

  Future<List<SupplierPerformance>> fetchTopSuppliers({String? fromDate, String? toDate}) async {
  final records = await outboxRepo.fetchAll();
  final filtered = records.where((r) {
    if (fromDate != null && r.businessDate.compareTo(fromDate) < 0) return false;
    if (toDate != null && r.businessDate.compareTo(toDate) > 0) return false;
    return true;
  }).toList();

  final Map<String, double> valueBySupplier = {};
  final Map<String, int> countBySupplier = {};

  for (final r in filtered) {
    final payload = jsonDecode(r.payloadJson) as Map<String, dynamic>;
    final deliveries = (payload['deliveries'] as List? ?? []);
    for (final d in deliveries) {
      final supplier = (d['supplier'] as String?) ?? 'Unknown';
      final cost = (d['totalCost'] as num?)?.toDouble() ?? 0.0;
      valueBySupplier[supplier] = (valueBySupplier[supplier] ?? 0.0) + cost;
      countBySupplier[supplier] = (countBySupplier[supplier] ?? 0) + 1;
    }
  }

  final result = valueBySupplier.keys.map((s) => SupplierPerformance(
    supplier: s,
    totalDeliveryValue: valueBySupplier[s] ?? 0.0,
    deliveryCount: countBySupplier[s] ?? 0,
  )).toList();

  result.sort((a, b) => b.totalDeliveryValue.compareTo(a.totalDeliveryValue));
  return result.take(5).toList(); // top 5 only
}

Future<List<ExpenseCategoryTotal>> fetchExpenseBreakdown({String? fromDate, String? toDate}) async {
  final records = await outboxRepo.fetchAll();
  final filtered = records.where((r) {
    if (fromDate != null && r.businessDate.compareTo(fromDate) < 0) return false;
    if (toDate != null && r.businessDate.compareTo(toDate) > 0) return false;
    return true;
  }).toList();

  final Map<String, double> amountByCategory = {};

  for (final r in filtered) {
    final payload = jsonDecode(r.payloadJson) as Map<String, dynamic>;
    final expenses = (payload['expenses'] as List? ?? []);
    for (final e in expenses) {
      final category = (e['category'] as String?) ?? 'Other';
      final amount = (e['amount'] as num?)?.toDouble() ?? 0.0;
      amountByCategory[category] = (amountByCategory[category] ?? 0.0) + amount;
    }
  }

  final result = amountByCategory.keys.map((c) => ExpenseCategoryTotal(
    category: c,
    amount: amountByCategory[c] ?? 0.0,
  )).toList();

  result.sort((a, b) => b.amount.compareTo(a.amount));
  return result;
}

Future<List<DebtSummary>> fetchDebtOverview({String? fromDate, String? toDate}) async {
  final records = await outboxRepo.fetchAll();
  final filtered = records.where((r) {
    if (fromDate != null && r.businessDate.compareTo(fromDate) < 0) return false;
    if (toDate != null && r.businessDate.compareTo(toDate) > 0) return false;
    return true;
  }).toList();

  final Map<String, DebtSummary> debtMap = {};

    for (final r in filtered) {
      final payload = jsonDecode(r.payloadJson) as Map<String, dynamic>;
      final debts = (payload['debts'] as List? ?? []);
      for (final d in debts) {
        final supplier = (d['supplier'] as String?) ?? 'Unknown';
        final fuelType = (d['fuelType'] as String?) ?? '';
        final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
        final settled = ((d['settled'] as int?) ?? 0) == 1;
        final key = '$supplier-$fuelType';

        if (debtMap.containsKey(key)) {
          debtMap[key] = DebtSummary(
            supplier: supplier,
            fuelType: fuelType,
            amount: (debtMap[key]!.amount) + amount,
            settled: settled,
          );
        } else {
          debtMap[key] = DebtSummary(
            supplier: supplier,
            fuelType: fuelType,
            amount: amount,
            settled: settled,
          );
        }
      }
    }

    final result = debtMap.values.toList();
    result.sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

  Future<List<ExternalPaymentSummary>> fetchExternalPayments({String? fromDate, String? toDate}) async {
    final records = await outboxRepo.fetchAll();
    final filtered = records.where((r) {
      if (fromDate != null && r.businessDate.compareTo(fromDate) < 0) return false;
      if (toDate != null && r.businessDate.compareTo(toDate) > 0) return false;
      return true;
    }).toList();

    final result = <ExternalPaymentSummary>[];

    for (final r in filtered) {
      final payload = jsonDecode(r.payloadJson) as Map<String, dynamic>;
      final payments = (payload['externalPayments'] as List? ?? []);
      for (final p in payments) {
        result.add(ExternalPaymentSummary(
          supplier: (p['supplier'] as String?) ?? 'Unknown',
          fuelType: (p['fuelType'] as String?) ?? '',
          kind: (p['kind'] as String?) ?? '',
          amount: (p['amount'] as num?)?.toDouble() ?? 0.0,
        ));
      }
    }

    result.sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

  Future<CashFlowSummary> fetchCashFlow({String? fromDate, String? toDate}) async {
    final records = await outboxRepo.fetchAll();
    final filtered = records.where((r) {
      if (fromDate != null && r.businessDate.compareTo(fromDate) < 0) return false;
      if (toDate != null && r.businessDate.compareTo(toDate) > 0) return false;
      return true;
    }).toList();

    double salesRevenue = 0;
    double expenses = 0;
    double debtSettlements = 0;
    double externalPayments = 0;

    for (final r in filtered) {
      final payload = jsonDecode(r.payloadJson) as Map<String, dynamic>;

      final sales = (payload['sales'] as List? ?? []);
      for (final s in sales) {
        salesRevenue += (s['totalAmount'] as num?)?.toDouble() ?? 0.0;
      }

      final exps = (payload['expenses'] as List? ?? []);
      for (final e in exps) {
        expenses += (e['amount'] as num?)?.toDouble() ?? 0.0;
      }

      final settlements = (payload['settlements'] as List? ?? []);
      for (final s in settlements) {
        debtSettlements += (s['paidAmount'] as num?)?.toDouble() ?? 0.0;
      }

      final extPayments = (payload['externalPayments'] as List? ?? []);
      for (final p in extPayments) {
        externalPayments += (p['amount'] as num?)?.toDouble() ?? 0.0;
      }
    }

    return CashFlowSummary(
      salesRevenue: salesRevenue,
      expenses: expenses,
      debtSettlements: debtSettlements,
      externalPayments: externalPayments,
    );
  }


}