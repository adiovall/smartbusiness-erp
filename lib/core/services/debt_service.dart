// lib/core/services/debt_service.dart

import '../models/debt_record.dart';

class DebtService {
  final List<DebtRecord> _debts = [];

  /// CREATE or MERGE debt (from delivery)
  void createDebt({
    required String supplier,
    required String fuelType,
    required double amount,
  }) {
    if (amount <= 0) return;

    final existing = getDebt(supplier, fuelType);

    if (existing != null) {
      existing.amount += amount;
      existing.settled = false;
    } else {
      _debts.add(
        DebtRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          supplier: supplier,
          fuelType: fuelType,
          amount: amount,
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  /// 🔍 GET specific debt
  DebtRecord? getDebt(String supplier, String fuelType) {
    try {
      return _debts.firstWhere(
        (d) =>
            d.supplier == supplier &&
            d.fuelType == fuelType &&
            !d.settled,
      );
    } catch (_) {
      return null;
    }
  }

  /// ✏ UPDATE debt amount
  void updateDebt(String debtId, double newAmount) {
    final debt = _debts.firstWhere((d) => d.id == debtId);

    debt.amount = newAmount;
    if (debt.amount <= 0) {
      debt.amount = 0;
      debt.settled = true;
    }
  }

  /// ❌ CLEAR debt (fully paid)
  void clearDebt(String debtId) {
    final debt = _debts.firstWhere((d) => d.id == debtId);
    debt.amount = 0;
    debt.settled = true;
  }

  /// 📊 TOTAL outstanding debt
  double get totalDebt =>
      _debts.where((d) => !d.settled).fold(
            0.0,
            (sum, d) => sum + d.amount,
          );

  /// 📊 Supplier total debt
  double totalDebtForSupplier(String supplier) {
    return _debts
        .where((d) => d.supplier == supplier && !d.settled)
        .fold(0.0, (sum, d) => sum + d.amount);
  }

  /// 📋 Read-only list
  List<DebtRecord> get allDebts =>
      List.unmodifiable(_debts);
}
