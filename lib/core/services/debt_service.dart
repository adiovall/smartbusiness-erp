// lib/core/services/debt_service.dart

import '../models/debt_record.dart';
import '../../features/fuel/repositories/debt_repo.dart';

class DebtService {
  final DebtRepo repo;
  final List<DebtRecord> _debts = [];

  DebtService(this.repo);

  /* ===================== INIT ===================== */

  /// Load all debts from SQLite into memory
  Future<void> loadFromDb() async {
    _debts
      ..clear()
      ..addAll(await repo.fetchAll());
  }

  /* ===================== CREATE ===================== */

  /// Create or merge debt (from delivery)
  Future<void> createDebt({
    required String supplier,
    required String fuelType,
    required double amount,
  }) async {
    if (amount <= 0) return;

    final existing = getDebt(supplier, fuelType);

    if (existing != null) {
      existing.amount += amount;
      existing.settled = false;
      await repo.update(existing);
    } else {
      final debt = DebtRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        supplier: supplier,
        fuelType: fuelType,
        amount: amount,
        createdAt: DateTime.now(),
      );

      _debts.add(debt);
      await repo.insert(debt);
    }
  }

  /* ===================== READ ===================== */

  /// Get active debt for supplier + fuel
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

  /// All debts (read-only)
  List<DebtRecord> get allDebts => List.unmodifiable(_debts);

  /* ===================== UPDATE ===================== */

  /// Update debt amount
  Future<void> updateDebt(String debtId, double newAmount) async {
    final debt = _debts.firstWhere((d) => d.id == debtId);

    debt.amount = newAmount;
    if (debt.amount <= 0) {
      debt.amount = 0;
      debt.settled = true;
    }

    await repo.update(debt);
  }

  /// Clear debt completely (fully paid)
  Future<void> clearDebt(String debtId) async {
    final debt = _debts.firstWhere((d) => d.id == debtId);

    debt.amount = 0;
    debt.settled = true;

    await repo.update(debt);
  }

  /* ===================== TOTALS ===================== */

  /// Total outstanding debt (all suppliers)
  double get totalDebt =>
      _debts.where((d) => !d.settled).fold(
            0.0,
            (sum, d) => sum + d.amount,
          );

  /// Total debt for one supplier
  double totalDebtForSupplier(String supplier) {
    return _debts
        .where((d) => d.supplier == supplier && !d.settled)
        .fold(0.0, (sum, d) => sum + d.amount);
  }
}
