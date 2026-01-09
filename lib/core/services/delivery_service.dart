// ==============================
// lib/core/services/delivery_service.dart
// ==============================

import '../models/delivery_record.dart';
import 'tank_service.dart';
import 'debt_service.dart';
import '../../features/fuel/repositories/delivery_repo.dart';

class DeliveryService {
  final TankService tankService;
  final DebtService debtService;
  final DeliveryRepo deliveryRepo;

  final List<DeliveryRecord> _deliveries = [];

  DeliveryService({
    required this.tankService,
    required this.debtService,
    required this.deliveryRepo,
  });

  Future<void> loadFromDb() async {
    _deliveries
      ..clear()
      ..addAll(await deliveryRepo.fetchAll());
  }

  /// ✅ Create draft delivery (editable/deletable until submit)
  /// Tank updates immediately and is reversible while draft.
  Future<DeliveryRecord> recordDraftDelivery({
    required String supplier,
    required String fuelType,
    required double liters,
    required double totalCost,
    required double amountPaid,
    required String source,
    double salesPaid = 0,
    double externalPaid = 0,
  }) async {
    if (supplier.trim().isEmpty) throw Exception('Supplier is required');
    if (liters <= 0) throw Exception('Delivered liters must be greater than zero');
    if (totalCost <= 0) throw Exception('Total cost must be greater than zero');
    if (amountPaid < 0) throw Exception('Paid cannot be negative');

    // ✅ Tank changes now (draft behavior)
    tankService.addFuel(fuelType, liters);

    // ✅ DO NOT apply credit/debt to business memory until submit
    final diff = amountPaid - totalCost;
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
      source: source,
      isSubmitted: 0, // ✅ draft
      debt: debt,
      credit: credit,
    );

    _deliveries.add(delivery);
    await deliveryRepo.insert(delivery);

    return delivery;
  }

  /// ✅ Edit draft delivery (full edit allowed until submit)
  /// Tank is adjusted by delta liters.
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
  }) async {
    final d = _deliveries.firstWhere((e) => e.id == id);

    if (d.isSubmitted == 1) {
      throw Exception('Cannot edit after submit');
    }

    if (supplier.trim().isEmpty) throw Exception('Supplier is required');
    if (liters <= 0) throw Exception('Liters must be greater than zero');
    if (totalCost <= 0) throw Exception('Total cost must be greater than zero');
    if (amountPaid < 0) throw Exception('Paid cannot be negative');

    // ✅ Tank: reverse old liters, apply new liters
    // If fuel type changes, move liters between tanks
    if (d.fuelType == fuelType) {
      final delta = liters - d.liters;
      if (delta > 0) {
        tankService.addFuel(fuelType, delta);
      } else if (delta < 0) {
        tankService.removeFuel(fuelType, delta.abs());
      }
    } else {
      // remove old from old tank, add new to new tank
      tankService.removeFuel(d.fuelType, d.liters);
      tankService.addFuel(fuelType, liters);
    }

    // recompute debt/credit for draft
    final diff = amountPaid - totalCost;
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
      source: source,
      isSubmitted: 0,
      debt: debt,
      credit: credit,
    );

    // replace in memory
    final idx = _deliveries.indexWhere((e) => e.id == id);
    _deliveries[idx] = updated;

    await deliveryRepo.update(updated);
    return updated;
  }

  /// ✅ Delete draft delivery (tank reverses)
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

  /// ✅ FINALIZE: submit all drafts for today
  /// Once submitted:
  /// - debts are created
  /// - credits become real and can be used later
  /// - records are locked from edit/delete
  Future<void> submitDraftDeliveries(List<DeliveryRecord> drafts) async {
    if (drafts.isEmpty) return;

    await deliveryRepo.markSubmittedByIds(drafts.map((e) => e.id).toList());

    for (final d in drafts) {
      // mark in-memory too
      final idx = _deliveries.indexWhere((x) => x.id == d.id);
      if (idx != -1) {
        _deliveries[idx] = DeliveryRecord(
          id: _deliveries[idx].id,
          date: _deliveries[idx].date,
          supplier: _deliveries[idx].supplier,
          fuelType: _deliveries[idx].fuelType,
          liters: _deliveries[idx].liters,
          totalCost: _deliveries[idx].totalCost,
          amountPaid: _deliveries[idx].amountPaid,
          salesPaid: _deliveries[idx].salesPaid,
          externalPaid: _deliveries[idx].externalPaid,
          source: _deliveries[idx].source,
          isSubmitted: 1,
          debt: _deliveries[idx].debt,
          credit: _deliveries[idx].credit,
        );
      }

      // ✅ NOW create debts (settlement memory starts now)
      if (d.debt > 0) {
        await debtService.createDebt(
          supplier: d.supplier,
          fuelType: d.fuelType,
          amount: d.debt,
        );
      }
    }
  }

  /// Credits only for SUBMITTED records (so delivery draft won’t affect it)
  double totalCreditForSupplier(String supplier) {
    return _deliveries
        .where((d) => d.isSubmitted == 1 && d.supplier == supplier && d.credit > 0)
        .fold(0.0, (sum, d) => sum + d.credit);
  }

  /// Consume credit only from SUBMITTED records
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
  }

  /// Settlement adds credit (SUBMITTED) so delivery can reuse later
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
      supplier: supplier,
      fuelType: fuelType,
      liters: 0,
      totalCost: 0,
      amountPaid: 0,
      salesPaid: 0,
      externalPaid: 0,
      source: source,
      isSubmitted: 1, // ✅ real credit
      debt: 0,
      credit: amount,
    );

    _deliveries.add(creditRecord);
    await deliveryRepo.insert(creditRecord);
  }
}
