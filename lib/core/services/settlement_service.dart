// lib/core/services/settlement_service.dart

import 'delivery_service.dart';
import 'debt_service.dart';

class SettlementService {
  final DeliveryService deliveryService;
  final DebtService debtService;

  SettlementService({
    required this.deliveryService,
    required this.debtService,
  });

  /// Settle supplier debt ONLY
  void settle({
    required String supplier,
    required double amount,
  }) {
    if (amount <= 0) return;

    debtService.settleDebt(
      supplier: supplier,
      amount: amount,
    );
  }

  /// Visible in Settlement UI
  double supplierDebt(String supplier) =>
      debtService.totalDebtForSupplier(supplier);

  double supplierCredit(String supplier) =>
      deliveryService.totalCreditForSupplier(supplier);

  double get totalDebt => debtService.totalDebt;

  double get totalCredit =>
      deliveryService.allDeliveries.fold(
        0.0,
        (s, d) => s + d.credit,
      );
}
