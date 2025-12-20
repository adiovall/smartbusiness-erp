// lib/core/services/settlement_service.dart

import '../models/settlement_record.dart';
import 'debt_service.dart';
import 'delivery_service.dart';

class SettlementService {
  final DebtService debtService;
  final DeliveryService deliveryService;

  SettlementService({
    required this.debtService,
    required this.deliveryService,
  });

  /// Apply settlement ONLY to debt
  SettlementRecord settle({
    required String supplier,
    required String fuelType,
    required double amount,
    required String source,
  }) {
    if (amount <= 0) {
      throw Exception('Settlement amount must be greater than zero');
    }

    final debt = debtService.getDebt(supplier, fuelType);

    double remainingDebt = 0;
    double credit = 0;

    if (debt != null) {
      if (amount >= debt.amount) {
        credit = amount - debt.amount; // extra becomes credit
        debtService.clearDebt(debt.id);
      } else {
        remainingDebt = debt.amount - amount;
        debtService.updateDebt(debt.id, remainingDebt);
      }
    } else {
      // No debt → full credit
      credit = amount;
    }

    // ✅ store credit so delivery can reuse it later
    if (credit > 0) {
      deliveryService.addCredit(
        supplier: supplier,
        fuelType: fuelType,
        amount: credit,
        source: 'Settlement',
      );
    }

    return SettlementRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      supplier: supplier,
      fuelType: fuelType,
      paidAmount: amount,
      remainingDebt: remainingDebt,
      credit: credit,
      source: source,
      date: DateTime.now(),
    );
  }

  double get totalDebt => debtService.totalDebt;

  double supplierCredit(String supplier) =>
      deliveryService.totalCreditForSupplier(supplier);
}
