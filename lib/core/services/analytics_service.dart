import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/fuel/domain/fuel_mapping.dart';

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

  FuelPerformance({required this.fuelType, required this.revenue, required this.liters});
}

class PumpPerformance {
  final String pumpNo;
  final double revenue;
  final double liters;

  PumpPerformance({required this.pumpNo, required this.revenue, required this.liters});
}

class FuelPriceTrend {
  final String businessDate;
  final Map<String, double> avgPriceByFuel;

  FuelPriceTrend({required this.businessDate, required this.avgPriceByFuel});
}

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

class ExpenseCategoryTotal {
  final String category;
  final double amount;

  ExpenseCategoryTotal({required this.category, required this.amount});
}

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

/// Replaces the local TankState dependency for analytics purposes —
/// this is the latest known tank reading as reported to Supabase,
/// not live local state. Used so a second device (e.g. Owner's own
/// machine) sees real tank levels without needing local data.
class TankLevelSnapshot {
  final String fuelType;
  final double capacity;
  final double currentLevel;
  final double percentage;

  TankLevelSnapshot({
    required this.fuelType,
    required this.capacity,
    required this.currentLevel,
    required this.percentage,
  });
}

enum InsightType { warning, positive, info }

class AiInsight {
  final InsightType type;
  final String title;
  final String detail;

  AiInsight({required this.type, required this.title, required this.detail});
}

class AiInsightEngine {
  static List<AiInsight> generate({
    required List<TankLevelSnapshot> tanks,
    required List<DayAnalytics> currentPeriod,
    required List<DayAnalytics> previousPeriod,
    required List<ExpenseCategoryTotal> expenseBreakdown,
    required List<ExpenseCategoryTotal> previousExpenseBreakdown,
    required List<DebtSummary> debts,
    required List<PumpPerformance> pumpPerformance,
    required List<FuelPerformance> fuelPerformance,
    required List<ExternalPaymentSummary> externalPayments,
    required String currentPeriodLabel,
  }) {
    final insights = <AiInsight>[];
    final money = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    for (final tank in tanks) {
      if (tank.percentage < 20) {
        insights.add(AiInsight(
          type: InsightType.warning,
          title: '${tank.fuelType} tank critically low',
          detail: '${tank.percentage.toInt()}% remaining (${tank.currentLevel.toStringAsFixed(0)}L of ${tank.capacity.toStringAsFixed(0)}L). Consider reordering soon.',
        ));
      } else if (tank.percentage < 35) {
        insights.add(AiInsight(
          type: InsightType.info,
          title: '${tank.fuelType} tank running low',
          detail: '${tank.percentage.toInt()}% remaining. Plan a delivery before stock runs out.',
        ));
      }
    }

    final currentShortage = expenseBreakdown
        .where((e) => e.category.toLowerCase().contains('shortage'))
        .fold(0.0, (s, e) => s + e.amount);
    final previousShortage = previousExpenseBreakdown
        .where((e) => e.category.toLowerCase().contains('shortage'))
        .fold(0.0, (s, e) => s + e.amount);

    if (currentShortage > 0 && previousShortage > 0) {
      final pct = ((currentShortage - previousShortage) / previousShortage * 100).round();
      if (pct > 10) {
        insights.add(AiInsight(
          type: InsightType.warning,
          title: 'Shortages increased by $pct%',
          detail: '${money.format(currentShortage)} in shortages this $currentPeriodLabel vs ${money.format(previousShortage)} previously. Check pump readings.',
        ));
      } else if (pct < -10) {
        insights.add(AiInsight(
          type: InsightType.positive,
          title: 'Shortages reduced by ${pct.abs()}%',
          detail: 'Shortage losses dropped to ${money.format(currentShortage)} this $currentPeriodLabel. Keep it up.',
        ));
      }
    } else if (currentShortage > 0 && previousShortage == 0) {
      insights.add(AiInsight(
        type: InsightType.warning,
        title: 'Shortages detected',
        detail: '${money.format(currentShortage)} in shortage losses recorded this $currentPeriodLabel.',
      ));
    }

    final currentRevenue = currentPeriod.fold(0.0, (s, d) => s + d.revenue);
    final previousRevenue = previousPeriod.fold(0.0, (s, d) => s + d.revenue);

    if (currentRevenue > 0 && previousRevenue > 0) {
      final pct = ((currentRevenue - previousRevenue) / previousRevenue * 100).round();
      if (pct >= 5) {
        insights.add(AiInsight(
          type: InsightType.positive,
          title: 'Revenue up $pct% vs last $currentPeriodLabel',
          detail: '${money.format(currentRevenue)} this $currentPeriodLabel vs ${money.format(previousRevenue)} previously. Great performance.',
        ));
      } else if (pct <= -10) {
        insights.add(AiInsight(
          type: InsightType.warning,
          title: 'Revenue down ${pct.abs()}% vs last $currentPeriodLabel',
          detail: '${money.format(currentRevenue)} this $currentPeriodLabel vs ${money.format(previousRevenue)} previously. Investigate the drop.',
        ));
      }
    }

    final unpaidDebts = debts.where((d) => !d.settled && d.amount > 0).toList();
    for (final d in unpaidDebts.take(3)) {
      insights.add(AiInsight(
        type: InsightType.warning,
        title: '${d.supplier} has outstanding debt',
        detail: '${money.format(d.amount)} unpaid for ${d.fuelType} delivery. Consider settling soon.',
      ));
    }

    if (pumpPerformance.isNotEmpty) {
      final best = pumpPerformance.reduce((a, b) => a.revenue > b.revenue ? a : b);
      final total = pumpPerformance.fold(0.0, (s, p) => s + p.revenue);
      final share = total > 0 ? (best.revenue / total * 100).round() : 0;
      if (pumpPerformance.length > 1) {
        insights.add(AiInsight(
          type: InsightType.positive,
          title: 'Pump ${best.pumpNo} is your top performer',
          detail: '${money.format(best.revenue)} revenue ($share% of total pump sales) this $currentPeriodLabel.',
        ));
      }
    }

    if (fuelPerformance.isNotEmpty) {
      final best = fuelPerformance.first;
      final total = fuelPerformance.fold(0.0, (s, f) => s + f.revenue);
      final share = total > 0 ? (best.revenue / total * 100).round() : 0;
      if (share >= 50) {
        insights.add(AiInsight(
          type: InsightType.positive,
          title: '${best.fuelType} drives $share% of revenue',
          detail: '${money.format(best.revenue)} from ${best.fuelType} this $currentPeriodLabel — your most profitable fuel.',
        ));
      }
    }

    if (externalPayments.isNotEmpty) {
      final suppliersThisPeriod = externalPayments.map((e) => e.supplier).toSet();
      final allKnownSuppliers = debts.map((d) => d.supplier).toSet();

      for (final supplier in allKnownSuppliers) {
        if (!suppliersThisPeriod.contains(supplier)) {
          insights.add(AiInsight(
            type: InsightType.info,
            title: 'No delivery from $supplier this $currentPeriodLabel',
            detail: 'Consider following up with $supplier — no deliveries recorded this $currentPeriodLabel.',
          ));
        }
      }
    }

    return insights;
  }
}

/// Reads live from Supabase instead of the local outbox — this is
/// what makes Analytics work correctly on a second device (e.g.
/// Owner's own machine) that has no local sales/delivery data of its
/// own. Every public method here keeps the exact same signature and
/// return type as the old local-outbox version, so none of the view
/// files (trends_view, insight_view, reconciliation_view) need to
/// change to use this.
class AnalyticsService {
  final SupabaseClient _client = Supabase.instance.client;

  bool _inRange(String date, String? from, String? to) {
    if (from != null && date.compareTo(from) < 0) return false;
    if (to != null && date.compareTo(to) > 0) return false;
    return true;
  }

  Future<List<DayAnalytics>> fetchTrend({String? fromDate, String? toDate}) async {
    final sales = await _client.from('sales').select('business_date, total_amount');
    final expenses = await _client.from('expenses').select('business_date, amount');
    final deliveries = await _client.from('deliveries').select('business_date, total_cost');

    final Map<String, double> revenueByDate = {};
    final Map<String, double> expenseByDate = {};
    final Map<String, double> deliveryByDate = {};

    for (final s in sales) {
      final d = s['business_date'] as String;
      if (!_inRange(d, fromDate, toDate)) continue;
      revenueByDate[d] = (revenueByDate[d] ?? 0) + ((s['total_amount'] as num?)?.toDouble() ?? 0);
    }
    for (final e in expenses) {
      final d = e['business_date'] as String;
      if (!_inRange(d, fromDate, toDate)) continue;
      expenseByDate[d] = (expenseByDate[d] ?? 0) + ((e['amount'] as num?)?.toDouble() ?? 0);
    }
    for (final del in deliveries) {
      final d = del['business_date'] as String;
      if (!_inRange(d, fromDate, toDate)) continue;
      deliveryByDate[d] = (deliveryByDate[d] ?? 0) + ((del['total_cost'] as num?)?.toDouble() ?? 0);
    }

    final allDates = {...revenueByDate.keys, ...expenseByDate.keys, ...deliveryByDate.keys}.toList()..sort();

    return allDates.map((d) {
      final revenue = revenueByDate[d] ?? 0.0;
      final expense = expenseByDate[d] ?? 0.0;
      final deliveryCost = deliveryByDate[d] ?? 0.0;
      return DayAnalytics(
        businessDate: d,
        revenue: revenue,
        expense: expense,
        deliveryCost: deliveryCost,
        net: revenue - expense,
      );
    }).toList();
  }

  /// Kept for compatibility with reconciliation_view.dart's pump table,
  /// which decodes this exact shape (businessDate + payloadJson with a
  /// 'sales' list using the original camelCase field names).
  Future<List<Map<String, dynamic>>> fetchRawOutbox({String? fromDate, String? toDate}) async {
    final rows = await _client.from('sales').select();
    final Map<String, List<Map<String, dynamic>>> byDate = {};

    for (final r in rows) {
      final date = r['business_date'] as String;
      if (!_inRange(date, fromDate, toDate)) continue;
      byDate.putIfAbsent(date, () => []).add({
        'pumpNo': r['pump_no'],
        'fuelType': r['fuel_type'],
        'opening': r['opening'],
        'closing': r['closing'],
        'liters': r['liters'],
        'unitPrice': r['unit_price'],
        'totalAmount': r['total_amount'],
      });
    }

    return byDate.entries
        .map((e) => {'businessDate': e.key, 'payloadJson': jsonEncode({'sales': e.value})})
        .toList();
  }

  /// Best-effort combined view of one business date across all tables.
  /// No confirmed caller in the current view files, kept for parity
  /// with the old API in case something elsewhere relies on it.
  Future<Map<String, dynamic>?> fetchDayDetail(String businessDate) async {
    final sales = await _client.from('sales').select().eq('business_date', businessDate);
    final deliveries = await _client.from('deliveries').select().eq('business_date', businessDate);
    final expenses = await _client.from('expenses').select().eq('business_date', businessDate);
    final settlements = await _client.from('settlements').select().eq('business_date', businessDate);
    final debts = await _client.from('debts').select().eq('business_date', businessDate);
    final externalPayments = await _client.from('external_payments').select().eq('business_date', businessDate);
    final tankSnapshot = await _client.from('tank_snapshots').select().eq('business_date', businessDate);

    if (sales.isEmpty && deliveries.isEmpty && expenses.isEmpty && settlements.isEmpty) return null;

    return {
      'businessDate': businessDate,
      'sales': sales,
      'deliveries': deliveries,
      'expenses': expenses,
      'settlements': settlements,
      'debts': debts,
      'externalPayments': externalPayments,
      'tankSnapshot': tankSnapshot,
    };
  }

  Future<List<String>> fetchAvailableDates() async {
    final rows = await _client.from('sales').select('business_date');
    final dates = rows.map((r) => r['business_date'] as String).toSet().toList();
    dates.sort();
    return dates;
  }

  Future<List<FuelPerformance>> fetchFuelPerformance({String? fromDate, String? toDate}) async {
    final rows = await _client.from('sales').select('business_date, fuel_type, total_amount, liters');

    final Map<String, double> revenueByFuel = {};
    final Map<String, double> litersByFuel = {};

    for (final r in rows) {
      final date = r['business_date'] as String;
      if (!_inRange(date, fromDate, toDate)) continue;
      final fuel = FuelMapping.tankKey(r['fuel_type'] as String);
      revenueByFuel[fuel] = (revenueByFuel[fuel] ?? 0) + ((r['total_amount'] as num?)?.toDouble() ?? 0);
      litersByFuel[fuel] = (litersByFuel[fuel] ?? 0) + ((r['liters'] as num?)?.toDouble() ?? 0);
    }

    final result = revenueByFuel.keys
        .map((f) => FuelPerformance(fuelType: f, revenue: revenueByFuel[f]!, liters: litersByFuel[f] ?? 0))
        .toList();
    result.sort((a, b) => b.revenue.compareTo(a.revenue));
    return result;
  }

  Future<List<FuelPriceTrend>> fetchPriceTrend({String? fromDate, String? toDate}) async {
    final rows = await _client.from('sales').select('business_date, fuel_type, total_amount, liters');

    final Map<String, Map<String, double>> amountByDateFuel = {};
    final Map<String, Map<String, double>> litersByDateFuel = {};

    for (final r in rows) {
      final date = r['business_date'] as String;
      if (!_inRange(date, fromDate, toDate)) continue;
      final fuel = FuelMapping.tankKey((r['fuel_type'] as String?) ?? 'Unknown');
      amountByDateFuel.putIfAbsent(date, () => {});
      litersByDateFuel.putIfAbsent(date, () => {});
      amountByDateFuel[date]![fuel] = (amountByDateFuel[date]![fuel] ?? 0) + ((r['total_amount'] as num?)?.toDouble() ?? 0);
      litersByDateFuel[date]![fuel] = (litersByDateFuel[date]![fuel] ?? 0) + ((r['liters'] as num?)?.toDouble() ?? 0);
    }

    final dates = amountByDateFuel.keys.toList()..sort();

    return dates.map((date) {
      final amounts = amountByDateFuel[date]!;
      final liters = litersByDateFuel[date]!;
      final avgPrices = <String, double>{};
      for (final fuel in amounts.keys) {
        final l = liters[fuel] ?? 0.0;
        avgPrices[fuel] = l > 0 ? amounts[fuel]! / l : 0.0;
      }
      return FuelPriceTrend(businessDate: date, avgPriceByFuel: avgPrices);
    }).toList();
  }

  Future<List<PumpPerformance>> fetchPumpPerformance({String? fromDate, String? toDate}) async {
    final rows = await _client.from('sales').select('business_date, pump_no, total_amount, liters');

    final Map<String, double> revenueByPump = {};
    final Map<String, double> litersByPump = {};

    for (final r in rows) {
      final date = r['business_date'] as String;
      if (!_inRange(date, fromDate, toDate)) continue;
      final pump = (r['pump_no'] as String?) ?? 'Unknown';
      revenueByPump[pump] = (revenueByPump[pump] ?? 0) + ((r['total_amount'] as num?)?.toDouble() ?? 0);
      litersByPump[pump] = (litersByPump[pump] ?? 0) + ((r['liters'] as num?)?.toDouble() ?? 0);
    }

    final result = revenueByPump.keys
        .map((p) => PumpPerformance(pumpNo: p, revenue: revenueByPump[p]!, liters: litersByPump[p] ?? 0))
        .toList();

    result.sort((a, b) {
      final aNum = int.tryParse(a.pumpNo);
      final bNum = int.tryParse(b.pumpNo);
      if (aNum != null && bNum != null) return aNum.compareTo(bNum);
      return a.pumpNo.compareTo(b.pumpNo);
    });

    return result;
  }

  Future<List<SupplierPerformance>> fetchTopSuppliers({String? fromDate, String? toDate}) async {
    final rows = await _client.from('deliveries').select('business_date, supplier, total_cost');

    final Map<String, double> valueBySupplier = {};
    final Map<String, int> countBySupplier = {};

    for (final r in rows) {
      final date = r['business_date'] as String;
      if (!_inRange(date, fromDate, toDate)) continue;
      final supplier = (r['supplier'] as String?) ?? 'Unknown';
      valueBySupplier[supplier] = (valueBySupplier[supplier] ?? 0) + ((r['total_cost'] as num?)?.toDouble() ?? 0);
      countBySupplier[supplier] = (countBySupplier[supplier] ?? 0) + 1;
    }

    final result = valueBySupplier.keys
        .map((s) => SupplierPerformance(
              supplier: s,
              totalDeliveryValue: valueBySupplier[s]!,
              deliveryCount: countBySupplier[s] ?? 0,
            ))
        .toList();

    result.sort((a, b) => b.totalDeliveryValue.compareTo(a.totalDeliveryValue));
    return result.take(5).toList();
  }

  Future<List<ExpenseCategoryTotal>> fetchExpenseBreakdown({String? fromDate, String? toDate}) async {
    final rows = await _client.from('expenses').select('business_date, category, amount');

    final Map<String, double> amountByCategory = {};
    for (final r in rows) {
      final date = r['business_date'] as String;
      if (!_inRange(date, fromDate, toDate)) continue;
      final category = (r['category'] as String?) ?? 'Other';
      amountByCategory[category] = (amountByCategory[category] ?? 0) + ((r['amount'] as num?)?.toDouble() ?? 0);
    }

    final result = amountByCategory.entries.map((e) => ExpenseCategoryTotal(category: e.key, amount: e.value)).toList();
    result.sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

  Future<List<DebtSummary>> fetchDebtOverview({String? fromDate, String? toDate}) async {
    final rows = await _client.from('debts').select('business_date, supplier, fuel_type, amount, settled');

    final Map<String, DebtSummary> debtMap = {};
    for (final r in rows) {
      final date = r['business_date'] as String;
      if (!_inRange(date, fromDate, toDate)) continue;
      final supplier = (r['supplier'] as String?) ?? 'Unknown';
      final fuelType = FuelMapping.tankKey((r['fuel_type'] as String?) ?? '');
      final amount = (r['amount'] as num?)?.toDouble() ?? 0.0;
      final settled = (r['settled'] as bool?) ?? false;
      final key = '$supplier-$fuelType';

      if (debtMap.containsKey(key)) {
        debtMap[key] = DebtSummary(
          supplier: supplier,
          fuelType: fuelType,
          amount: debtMap[key]!.amount + amount,
          settled: settled,
        );
      } else {
        debtMap[key] = DebtSummary(supplier: supplier, fuelType: fuelType, amount: amount, settled: settled);
      }
    }

    final result = debtMap.values.toList();
    result.sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

  Future<List<ExternalPaymentSummary>> fetchExternalPayments({String? fromDate, String? toDate}) async {
    final rows = await _client.from('external_payments').select('business_date, supplier, fuel_type, kind, amount');

    final result = <ExternalPaymentSummary>[];
    for (final r in rows) {
      final date = r['business_date'] as String;
      if (!_inRange(date, fromDate, toDate)) continue;
      result.add(ExternalPaymentSummary(
        supplier: (r['supplier'] as String?) ?? 'Unknown',
        fuelType: FuelMapping.tankKey((r['fuel_type'] as String?) ?? ''),
        kind: (r['kind'] as String?) ?? '',
        amount: (r['amount'] as num?)?.toDouble() ?? 0.0,
      ));
    }

    result.sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

  Future<CashFlowSummary> fetchCashFlow({String? fromDate, String? toDate}) async {
    final sales = await _client.from('sales').select('business_date, total_amount');
    final expenses = await _client.from('expenses').select('business_date, amount');
    final settlements = await _client.from('settlements').select('business_date, paid_amount');
    final externalPayments = await _client.from('external_payments').select('business_date, amount');

    double salesRevenue = 0, exp = 0, debtSettlements = 0, extPay = 0;

    for (final s in sales) {
      if (_inRange(s['business_date'] as String, fromDate, toDate)) {
        salesRevenue += (s['total_amount'] as num?)?.toDouble() ?? 0;
      }
    }
    for (final e in expenses) {
      if (_inRange(e['business_date'] as String, fromDate, toDate)) {
        exp += (e['amount'] as num?)?.toDouble() ?? 0;
      }
    }
    for (final s in settlements) {
      if (_inRange(s['business_date'] as String, fromDate, toDate)) {
        debtSettlements += (s['paid_amount'] as num?)?.toDouble() ?? 0;
      }
    }
    for (final p in externalPayments) {
      if (_inRange(p['business_date'] as String, fromDate, toDate)) {
        extPay += (p['amount'] as num?)?.toDouble() ?? 0;
      }
    }

    return CashFlowSummary(
      salesRevenue: salesRevenue,
      expenses: exp,
      debtSettlements: debtSettlements,
      externalPayments: extPay,
    );
  }

  /// Latest known reading per fuel type, for remote tank-level display
  /// (Insight view's Tank Levels section + AI insights). Replaces the
  /// dependency on local Services.tank.allTanks for analytics purposes.
  Future<List<TankLevelSnapshot>> fetchLatestTankLevels() async {
    final rows = await _client.from('tank_snapshots').select().order('business_date', ascending: false);

    final Map<String, Map<String, dynamic>> latestByFuel = {};
    for (final r in rows) {
      final fuel = FuelMapping.tankKey(r['fuel_type'] as String);
      latestByFuel.putIfAbsent(fuel, () => r);
    }

    return latestByFuel.values
        .map((r) => TankLevelSnapshot(
              fuelType: FuelMapping.tankKey(r['fuel_type'] as String),
              capacity: (r['capacity'] as num).toDouble(),
              currentLevel: (r['current_level'] as num).toDouble(),
              percentage: (r['percentage'] as num).toDouble(),
            ))
        .toList();
  }
}