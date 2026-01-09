// lib/core/services/settlement_service.dart

import '../models/settlement_record.dart';
import 'debt_service.dart';
import 'delivery_service.dart';
import '../../features/fuel/repositories/settlement_repo.dart';

class SettlementService {
  final DebtService debtService;
  final DeliveryService deliveryService;
  final SettlementRepo settlementRepo;

  SettlementService({
    required this.debtService,
    required this.deliveryService,
    required this.settlementRepo,
  });

  Future<SettlementRecord> settle({
    required String supplier,
    required String fuelType,
    required double amount,
    required String source,
  }) async {
    return settleSplit(
      supplier: supplier,
      fuelType: fuelType,
      salesPaid: amount,
      externalPaid: 0,
      source: source,
    );
  }

  Future<SettlementRecord> settleSplit({
    required String supplier,
    required String fuelType,
    required double salesPaid,
    required double externalPaid,
    required String source,
  }) async {
    final total = salesPaid + externalPaid;
    if (total <= 0) throw Exception('Settlement amount must be greater than zero');

    final debt = debtService.getDebt(supplier, fuelType);

    double remainingDebt = 0;
    double credit = 0;

    if (debt != null) {
      if (total >= debt.amount) {
        credit = total - debt.amount;
        await debtService.clearDebt(debt.id);
      } else {
        remainingDebt = debt.amount - total;
        await debtService.updateDebt(debt.id, remainingDebt);
      }
    } else {
      credit = total;
    }

    if (credit > 0) {
      await deliveryService.addCredit(
        supplier: supplier,
        fuelType: fuelType,
        amount: credit,
        source: 'Settlement',
      );
    }

    final record = SettlementRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      supplier: supplier,
      fuelType: fuelType,
      paidAmount: total,
      salesPaid: salesPaid,
      externalPaid: externalPaid,
      remainingDebt: remainingDebt,
      credit: credit,
      source: source,
      date: DateTime.now(),
    );

    await settlementRepo.insert(record);
    return record;
  }

  double get totalDebt => debtService.totalDebt;

  double supplierCredit(String supplier) =>
      deliveryService.totalCreditForSupplier(supplier);
}
