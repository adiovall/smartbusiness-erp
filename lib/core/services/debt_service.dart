// lib/core/services/debt_service.dart

import 'package:flutter/foundation.dart';
import '../models/debt_record.dart';
import '../../features/fuel/repositories/debt_repo.dart';

class DebtService with ChangeNotifier {
  final DebtRepo repo;
  final List<DebtRecord> _debts = [];

  DebtService(this.repo);

  /* ===================== INIT ===================== */

  Future<void> loadFromDb() async {
    _debts
      ..clear()
      ..addAll(await repo.fetchAll());
    notifyListeners();
  }

  /* ===================== CREATE ===================== */

  /// Create a NEW, separately-dated debt record (from a delivery).
  /// Debts no longer merge into one running balance per supplier+fuel —
  /// each delivery's shortfall becomes its own record, tagged with
  /// today's businessDate, so it can be correctly tracked and reported
  /// per business day. Multiple open debts for the same supplier+fuel
  /// can coexist; settlements pay them down oldest-first (FIFO).
  Future<void> createDebt({
    required String supplier,
    required String fuelType,
    required double amount,
    String? businessDate,
  }) async {
    if (amount <= 0) return;

    final debt = DebtRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      supplier: supplier,
      fuelType: fuelType,
      amount: amount,
      createdAt: DateTime.now(),
      businessDate: businessDate,
    );

    _debts.add(debt);
    await repo.insert(debt);
    notifyListeners();
  }

  /* ===================== READ ===================== */

  /// All OPEN (unsettled) debts for a supplier+fuel, oldest first.
  List<DebtRecord> getOpenDebts(String supplier, String fuelType) {
    final list = _debts
        .where((d) =>
            d.supplier == supplier && d.fuelType == fuelType && !d.settled)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt)); // FIFO
    return list;
  }

  /// Backward-compatible single-debt getter: returns the OLDEST open
  /// debt for supplier+fuel, or null if none. Kept for any call sites
  /// that only need "is there debt at all" without caring about FIFO
  /// breakdown.
  DebtRecord? getDebt(String supplier, String fuelType) {
    final open = getOpenDebts(supplier, fuelType);
    return open.isEmpty ? null : open.first;
  }

  List<DebtRecord> get allDebts => List.unmodifiable(_debts);

  List<DebtRecord> allForBusinessDate(String businessDate) {
    return _debts.where((d) => d.businessDate == businessDate).toList();
  }

  /* ===================== UPDATE ===================== */

  Future<void> updateDebt(String debtId, double newAmount) async {
    final debt = _debts.firstWhere((d) => d.id == debtId);

    debt.amount = newAmount;
    if (debt.amount <= 0) {
      debt.amount = 0;
      debt.settled = true;
    }

    await repo.update(debt);
    notifyListeners();
  }

  Future<void> clearDebt(String debtId) async {
    final debt = _debts.firstWhere((d) => d.id == debtId);

    debt.amount = 0;
    debt.settled = true;

    await repo.update(debt);
    notifyListeners();
  }

  /// Pay down a supplier+fuel's open debts FIFO with a single payment
  /// amount. Oldest debt is paid first; if the payment exceeds that
  /// debt, the remainder spills over to pay the next-oldest, and so
  /// on, until the payment is exhausted or all debts are settled.
  ///
  /// Returns the total amount actually applied (in case the payment
  /// was larger than total outstanding debt — caller decides what to
  /// do with any leftover, e.g. treat as overpaid credit).
  Future<double> payDownFifo({
    required String supplier,
    required String fuelType,
    required double payment,
  }) async {
    double remaining = payment;
    final open = getOpenDebts(supplier, fuelType);

    for (final debt in open) {
      if (remaining <= 0) break;

      final applied = remaining >= debt.amount ? debt.amount : remaining;
      debt.amount -= applied;
      remaining -= applied;

      if (debt.amount <= 0) {
        debt.amount = 0;
        debt.settled = true;
      }

      await repo.update(debt);
    }

    notifyListeners();
    return payment - remaining; // total actually applied
  }

  /* ===================== TOTALS ===================== */

  double get totalDebt =>
      _debts.where((d) => !d.settled).fold(0.0, (sum, d) => sum + d.amount);

  double totalDebtForSupplier(String supplier) {
    return _debts
        .where((d) => d.supplier == supplier && !d.settled)
        .fold(0.0, (sum, d) => sum + d.amount);
  }

  /// Combined open debt for a specific supplier+fuel (sum across all
  /// open dated records) — useful where the UI needs "how much is
  /// owed in total" without caring about the FIFO breakdown.
  double totalOpenDebtForSupplierFuel(String supplier, String fuelType) {
    return getOpenDebts(supplier, fuelType)
        .fold(0.0, (sum, d) => sum + d.amount);
  }

  /* ===================== BUSINESS DATE CORRECTION ===================== */

  Future<void> moveBusinessDate(String oldBusinessDate, String newBusinessDate) async {
    for (final debt in _debts.where((d) => d.businessDate == oldBusinessDate)) {
      debt.businessDate = newBusinessDate;
    }
    await repo.updateBusinessDate(oldBusinessDate, newBusinessDate);
    notifyListeners();
  }
}