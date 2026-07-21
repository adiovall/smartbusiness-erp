// lib/core/services/settlement_service.dart

import '../models/settlement_record.dart';
import 'debt_service.dart';
import 'delivery_service.dart';
import '../../features/fuel/repositories/settlement_repo.dart';
import 'expense_service.dart'; 
import '../models/debt_payment_record.dart';
import '../../features/fuel/repositories/debt_payment_repo.dart';// ✅ add

class SettlementService {
  final DebtService debtService;
  final DeliveryService deliveryService;
  final SettlementRepo settlementRepo;
  final ExpenseService expenseService; 
  final DebtPaymentRepo debtPaymentRepo;

  SettlementService({
    required this.debtService,
    required this.deliveryService,
    required this.settlementRepo,
    required this.expenseService, 
    required this.debtPaymentRepo,// ✅ add
  });

  /// NEW: moves all settlements tagged with oldDate to newDate.
  Future<void> moveBusinessDate(String oldDate, String newDate) async {
    await settlementRepo.updateBusinessDate(oldDate, newDate);
  }

  Future<List<SettlementRecord>> allForBusinessDate(String businessDate) async {
    return settlementRepo.fetchAllForBusinessDate(businessDate);
  }

  Future<SettlementRecord> settleSplit({
    required String supplier,
    required String fuelType,
    required double salesPaid,
    required double externalPaid,
    required String source,
    required String businessDate,
  }) async {
    final total = salesPaid + externalPaid;
    if (total <= 0) throw Exception('Settlement amount must be greater than zero');

    final debt = debtService.getDebt(supplier, fuelType);

    if (debt != null && total > debt.amount) {
      throw Exception(
        'Overpayment blocked: outstanding debt is ₦${debt.amount.toStringAsFixed(0)}, '
        'but you entered ₦${total.toStringAsFixed(0)}. Reduce the settlement amount.'
      );
    }

    double remainingDebt = 0;
    double credit = 0;
    double appliedToDebt = 0;
    final affectedDebtId = debt?.id;

    if (debt != null) {
      appliedToDebt = total >= debt.amount ? debt.amount : total;
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
      businessDate: businessDate,
    );

    await settlementRepo.insert(record);

    if (affectedDebtId != null && appliedToDebt > 0) {
      await debtPaymentRepo.insert(DebtPaymentRecord(
        id: '${DateTime.now().millisecondsSinceEpoch}_$affectedDebtId',
        debtId: affectedDebtId,
        amount: appliedToDebt,
        paidByBusinessDate: businessDate,
        paidByRefId: 'SET:${record.id}',
        createdAt: DateTime.now(),
      ));
    }

    if (salesPaid > 0) {
      await expenseService.createLockedExpense(
        amount: salesPaid,
        category: 'Settlement Payment',
        comment: '$supplier • $fuelType',
        source: 'Sales',
        refId: 'SET:${record.id}',
        date: record.date,
        businessDate: businessDate,
      );
    }

    return record;
  }

  Future<void> deleteAllForBusinessDate(String businessDate) async {
    // Reverse: settlements made ON this day may have paid down debts
    // that originated on a different day — restore those first.
    final payments = await debtPaymentRepo.fetchForBusinessDate(businessDate);
    for (final p in payments) {
      await debtService.restorePayment(p.debtId, p.amount);
    }
    await debtPaymentRepo.deleteForBusinessDate(businessDate);
    await settlementRepo.deleteForBusinessDate(businessDate);
  }

  Future<int> todaySubmittedCount(String businessDate, bool alreadySent) =>
    settlementRepo.countPendingForBusinessDate(businessDate, alreadySent);
}
