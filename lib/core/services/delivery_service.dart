import '../models/delivery_record.dart';
import 'tank_service.dart';
import 'debt_service.dart';

class DeliveryService {
  final TankService tankService;
  final DebtService debtService;

  final List<DeliveryRecord> _deliveries = [];

  DeliveryService({
    required this.tankService,
    required this.debtService,
  });

  DeliveryRecord recordDelivery({
    required String supplier,
    required String fuelType,
    required double liters,
    required double totalCost,
    required double amountPaid,
    required String source,
  }) {
    if (liters <= 0) {
      throw Exception('Delivered liters must be greater than zero');
    }

    if (totalCost < 0 || amountPaid < 0) {
      throw Exception('Amounts cannot be negative');
    }

    // 1️⃣ APPLY EXISTING CREDIT FIRST
    final double creditAvailable =
        totalCreditForSupplier(supplier);

    double adjustedCost = totalCost;
    double usedCredit = 0;

    if (creditAvailable > 0) {
      usedCredit =
          creditAvailable >= totalCost ? totalCost : creditAvailable;
      adjustedCost -= usedCredit;
      _consumeCredit(supplier, usedCredit);
    }

    // 2️⃣ Calculate final difference
    final diff = amountPaid - adjustedCost;

    double debt = 0;
    double credit = 0;

    if (diff < 0) {
      debt = diff.abs();
    } else if (diff > 0) {
      credit = diff;
    }

    // 3️⃣ Increase tank
    tankService.addFuel(fuelType, liters);

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

    // 5️⃣ Create debt ONLY
    if (debt > 0) {
      debtService.createDebt(
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
        .where((d) => d.supplier == supplier)
        .fold(0.0, (sum, d) => sum + d.credit);
  }

  /// CONSUME CREDIT (FIFO)
  void _consumeCredit(String supplier, double amount) {
    double remaining = amount;

    for (final d in _deliveries) {
      if (d.supplier != supplier || d.credit <= 0) continue;

      final used = d.credit >= remaining ? remaining : d.credit;
      d.credit -= used;
      remaining -= used;

      if (remaining <= 0) break;
    }
  }

  List<DeliveryRecord> get todayDeliveries =>
      _deliveries.where((d) => _isToday(d.date)).toList();

  List<DeliveryRecord> get allDeliveries =>
      List.unmodifiable(_deliveries);

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year &&
        d.month == now.month &&
        d.day == now.day;
  }
}
