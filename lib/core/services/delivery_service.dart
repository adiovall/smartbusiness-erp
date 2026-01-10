// ==============================
// lib/core/services/delivery_service.dart
// ==============================

import '../models/delivery_record.dart';
import 'tank_service.dart';
import 'debt_service.dart';
import 'expense_service.dart';
import '../../features/fuel/repositories/delivery_repo.dart';

class DeliveryService {
  final TankService tankService;
  final DebtService debtService;
  final ExpenseService expenseService;
  final DeliveryRepo deliveryRepo;

  final List<DeliveryRecord> _deliveries = [];

  DeliveryService({
    required this.tankService,
    required this.debtService,
    required this.expenseService,
    required this.deliveryRepo,
  });

  Future<void> loadFromDb() async {
    _deliveries
      ..clear()
      ..addAll(await deliveryRepo.fetchAll());
  }

  double totalCreditForSupplier(String supplier) {
    return _deliveries
        .where((d) => d.isSubmitted == 1 && d.supplier == supplier && d.credit > 0)
        .fold(0.0, (sum, d) => sum + d.credit);
  }

  Future<void> consumeCredit(String supplier, double amount) async {
    double remaining = amount;

    for (int i = 0; i < _deliveries.length; i++) {
      final d = _deliveries[i];
      if (d.isSubmitted != 1) continue;
      if (d.supplier != supplier || d.credit <= 0) continue;

      final used = d.credit >= remaining ? remaining : d.credit;
      d.credit -= used;
      remaining -= used;

      await deliveryRepo.update(d);

      if (remaining <= 0) break;
    }

    if (remaining > 0.01) {
      // means credits changed elsewhere
      throw Exception('Not enough overpaid credit available');
    }
  }


    /// ✅ Settlement overpaid → store as supplier credit (SUBMITTED)
  /// This does NOT touch tanks. It only creates a credit row that delivery can consume later.
  Future<void> addCredit({
    required String supplier,
    required String fuelType,
    required double amount,
    required String source,
  }) async {
    if (amount <= 0) return;

    final creditRecord = DeliveryRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      supplier: supplier.trim(),
      fuelType: fuelType,
      liters: 0,
      totalCost: 0,
      amountPaid: 0,
      salesPaid: 0,
      externalPaid: 0,
      creditUsed: 0, // ✅ important since your model now has it
      source: source,
      isSubmitted: 1, // ✅ credit is real immediately
      debt: 0,
      credit: amount,
    );

    _deliveries.add(creditRecord);
    await deliveryRepo.insert(creditRecord);
  }



  /// ✅ Create draft delivery (editable/deletable until submit)
  Future<DeliveryRecord> recordDraftDelivery({
    required String supplier,
    required String fuelType,
    required double liters,
    required double totalCost,
    required double amountPaid,
    required String source,
    required double salesPaid,
    required double externalPaid,
    required double creditUsed,
  }) async {
    if (supplier.trim().isEmpty) throw Exception('Supplier is required');
    if (liters <= 0) throw Exception('Delivered liters must be greater than zero');
    if (totalCost <= 0) throw Exception('Total cost must be greater than zero');
    if (amountPaid < 0) throw Exception('Paid cannot be negative');
    if (creditUsed < 0) throw Exception('Credit used cannot be negative');

    final tank = tankService.getTank(fuelType);
    if (tank != null && (tank.currentLevel + liters) > tank.capacity + 0.0001) {
      throw Exception('Delivery exceeds tank capacity. Update tank capacity first.');
    }


    // tank changes now (draft behavior)
    tankService.addFuel(fuelType, liters);

    // effective paid includes creditUsed
    final effectivePaid = amountPaid + creditUsed;
    final diff = effectivePaid - totalCost;

    final debt = diff < 0 ? diff.abs() : 0.0;
    final credit = diff > 0 ? diff : 0.0;

    final delivery = DeliveryRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      supplier: supplier.trim(),
      fuelType: fuelType,
      liters: liters,
      totalCost: totalCost,
      amountPaid: amountPaid,
      salesPaid: salesPaid,
      externalPaid: externalPaid,
      creditUsed: creditUsed,
      source: source,
      isSubmitted: 0,
      debt: debt,
      credit: credit,
    );

    _deliveries.add(delivery);
    await deliveryRepo.insert(delivery);

    return delivery;
  }

  /// ✅ Edit draft delivery (full edit allowed until submit)
  Future<DeliveryRecord> editDraftDelivery({
    required String id,
    required String supplier,
    required String fuelType,
    required double liters,
    required double totalCost,
    required double amountPaid,
    required String source,
    required double salesPaid,
    required double externalPaid,
    required double creditUsed,
  }) async {
    final d = _deliveries.firstWhere((e) => e.id == id);

    if (d.isSubmitted == 1) {
      throw Exception('Cannot edit after submit');
    }

    if (supplier.trim().isEmpty) throw Exception('Supplier is required');
    if (liters <= 0) throw Exception('Liters must be greater than zero');
    if (totalCost <= 0) throw Exception('Total cost must be greater than zero');
    if (amountPaid < 0) throw Exception('Paid cannot be negative');
    if (creditUsed < 0) throw Exception('Credit used cannot be negative');

    // Tank adjust
    if (d.fuelType == fuelType) {
  final delta = liters - d.liters;
  if (delta > 0) {
    final tank = tankService.getTank(fuelType);
    if (tank != null && (tank.currentLevel + delta) > tank.capacity + 0.0001) {
      throw Exception('Update exceeds tank capacity. Update tank capacity first.');
    }
  }
} else {
  final newTank = tankService.getTank(fuelType);
  if (newTank != null && (newTank.currentLevel + liters) > newTank.capacity + 0.0001) {
    throw Exception('New fuel tank capacity exceeded. Update tank capacity first.');
  }
}


    final effectivePaid = amountPaid + creditUsed;
    final diff = effectivePaid - totalCost;

    final debt = diff < 0 ? diff.abs() : 0.0;
    final credit = diff > 0 ? diff : 0.0;

    final updated = DeliveryRecord(
      id: d.id,
      date: d.date,
      supplier: supplier.trim(),
      fuelType: fuelType,
      liters: liters,
      totalCost: totalCost,
      amountPaid: amountPaid,
      salesPaid: salesPaid,
      externalPaid: externalPaid,
      creditUsed: creditUsed,
      source: source,
      isSubmitted: 0,
      debt: debt,
      credit: credit,
    );

    final idx = _deliveries.indexWhere((e) => e.id == id);
    _deliveries[idx] = updated;

    await deliveryRepo.update(updated);
    return updated;
  }

  Future<void> deleteDraftDelivery(String id) async {
    final d = _deliveries.firstWhere((e) => e.id == id);

    if (d.isSubmitted == 1) {
      throw Exception('Cannot delete after submit');
    }

    // reverse tank addition
    if (d.liters > 0) {
      tankService.removeFuel(d.fuelType, d.liters);
    }

    _deliveries.removeWhere((e) => e.id == id);
    await deliveryRepo.deleteById(id);
  }

  /// ✅ FINALIZE: submit drafts
  /// - consume overpaid credits used
  /// - create locked expense for salesPaid
  /// - create debt records
  Future<void> submitDraftDeliveries(List<DeliveryRecord> drafts) async {
    if (drafts.isEmpty) return;

    // 1) mark submitted in DB
    await deliveryRepo.markSubmittedByIds(drafts.map((e) => e.id).toList());

    for (final d in drafts) {
      // 2) consume overpaid credit (if used)
      if (d.creditUsed > 0) {
        await consumeCredit(d.supplier, d.creditUsed);
      }

      // 3) create locked expense for sales part
      if (d.salesPaid > 0) {
        await expenseService.createLockedExpense(
          amount: d.salesPaid,
          category: 'Delivery Payment',
          comment: '${d.supplier} • ${d.fuelType}',
          source: 'Sales',
          refId: 'DEL:${d.id}',
          date: DateTime.now(),
        );
      }

      // 4) create debt record (only now)
      if (d.debt > 0) {
        await debtService.createDebt(
          supplier: d.supplier,
          fuelType: d.fuelType,
          amount: d.debt,
        );
      }

      // 5) mark in memory
      final idx = _deliveries.indexWhere((x) => x.id == d.id);
      if (idx != -1) {
        final old = _deliveries[idx];
        _deliveries[idx] = DeliveryRecord(
          id: old.id,
          date: old.date,
          supplier: old.supplier,
          fuelType: old.fuelType,
          liters: old.liters,
          totalCost: old.totalCost,
          amountPaid: old.amountPaid,
          salesPaid: old.salesPaid,
          externalPaid: old.externalPaid,
          creditUsed: old.creditUsed,
          source: old.source,
          isSubmitted: 1,
          debt: old.debt,
          credit: old.credit,
        );
      }
    }
  }
}

