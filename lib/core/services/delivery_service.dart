// lib/core/services/delivery_service.dart

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

  /// ✅ MUST: load persisted history for tracking
  Future<void> loadFromDb() async {
    _deliveries
      ..clear()
      ..addAll(await deliveryRepo.fetchAll());
  }

  Future<DeliveryRecord> recordDelivery({
    required String supplier,
    required String fuelType,
    required double liters,
    required double totalCost,
    required double amountPaid,
    required String source,
  }) async {
    if (liters <= 0) throw Exception('Delivered liters must be greater than zero');
    if (totalCost < 0 || amountPaid < 0) throw Exception('Amounts cannot be negative');

    // 1️⃣ APPLY EXISTING CREDIT FIRST
    final double creditAvailable = totalCreditForSupplier(supplier);

    double adjustedCost = totalCost;

    if (creditAvailable > 0) {
      final usedCredit = creditAvailable >= totalCost ? totalCost : creditAvailable;
      adjustedCost -= usedCredit;

      // ✅ persist credit reduction to DB
      await _consumeCreditPersisted(supplier, usedCredit);
    }

    // 2️⃣ Final difference after credit
    final diff = amountPaid - adjustedCost;

    double debt = 0;
    double credit = 0;

    if (diff < 0) {
      debt = diff.abs();
    } else if (diff > 0) {
      credit = diff;
    }

    // 3️⃣ Increase tank (await if async)
    await tankService.addFuel(fuelType, liters);

    // 4️⃣ Create record
    final delivery = DeliveryRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      supplier: supplier,
      fuelType: fuelType,
      liters: liters,
      totalCost: totalCost,
      amountPaid: amountPaid,
      source: source,
      debt: debt,
      credit: credit,
    );

    _deliveries.add(delivery);
    await deliveryRepo.insert(delivery);

    // 5️⃣ Create debt ONLY
    if (debt > 0) {
      await debtService.createDebt(
        supplier: supplier,
        fuelType: fuelType,
        amount: debt,
      );
    }

    return delivery;
  }

  /// TOTAL CREDIT FOR SUPPLIER
  double totalCreditForSupplier(String supplier) {
    return _deliveries
        .where((d) => d.supplier == supplier && d.credit > 0)
        .fold(0.0, (sum, d) => sum + d.credit);
  }

  /// ✅ CONSUME CREDIT (FIFO) + persist updates
  Future<void> _consumeCreditPersisted(String supplier, double amount) async {
    double remaining = amount;

    for (final d in _deliveries) {
      if (d.supplier != supplier || d.credit <= 0) continue;

      final used = d.credit >= remaining ? remaining : d.credit;
      d.credit -= used;
      remaining -= used;

      await deliveryRepo.update(d); // ✅ save new credit value

      if (remaining <= 0) break;
    }
  }

  List<DeliveryRecord> get todayDeliveries =>
      _deliveries.where((d) => _isToday(d.date)).toList();

  List<DeliveryRecord> get allDeliveries => List.unmodifiable(_deliveries);

  double get todayTotalCost =>
      todayDeliveries.fold(0.0, (sum, d) => sum + d.totalCost);

  double get todayTotalLiters =>
      todayDeliveries.fold(0.0, (sum, d) => sum + d.liters);

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  /// ✅ Add CREDIT without affecting tank stock (used by settlement)
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
      source: source,
      debt: 0,
      credit: amount,
    );

    _deliveries.add(creditRecord);
    await deliveryRepo.insert(creditRecord);
  }
}
