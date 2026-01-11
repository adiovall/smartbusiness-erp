// lib/core/services/sale_service.dart

import 'dart:math';
import '../models/sale_record.dart';
import '../../features/fuel/repositories/sale_repo.dart';
import 'tank_service.dart';

class SaleMismatch {
  final double difference;
  final bool isShortage; // true if money received < sold

  SaleMismatch(this.difference) : isShortage = difference > 0;

  double get absolute => difference.abs();
}

class SaleService {
  final TankService tankService;
  final SaleRepo saleRepo;

  /// optional draft cache (only used if you decide to use recordDraftSale)
  final List<SaleRecord> _draftSales = [];

  SaleService({
    required this.tankService,
    required this.saleRepo,
  });

  SaleRecord recordDraftSale({
    required String pumpNo,
    required String fuelType,
    required double opening,
    required double closing,
    required double unitPrice,
  }) {
    final liters = max(0.0, closing - opening);

    if (liters <= 0) throw Exception('Closing meter must be greater than opening');
    if (unitPrice <= 0) throw Exception('Unit price must be greater than zero');

    final tank = tankService.getTank(fuelType);
    if (tank != null && liters > tank.currentLevel) {
      throw Exception('Not enough fuel in $fuelType tank (${tank.currentLevel}L available)');
    }

    final sale = SaleRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      pumpNo: pumpNo,
      fuelType: fuelType,
      liters: liters,
      unitPrice: unitPrice,
    );

    _draftSales.add(sale);
    return sale;
  }

  double get draftTotalAmount =>
      _draftSales.fold(0.0, (sum, s) => sum + s.totalAmount);

  List<SaleRecord> get draftSales => List.unmodifiable(_draftSales);

  void clearDraft() => _draftSales.clear();

  /// ✅ Now supports includeDraft
  Future<double> todayTotalAmount({bool includeDraft = false}) async {
    final committed = await saleRepo.fetchTodayTotalAmount();
    if (!includeDraft) return committed;

    // draft only counts if you’re using recordDraftSale (optional)
    return committed + draftTotalAmount;
  }

  SaleMismatch? checkMismatch({
    required double cashReceived,
    required double posReceived,
    required double totalSold,
  }) {
    final totalReceived = cashReceived + posReceived;
    final difference = totalSold - totalReceived;

    if (difference.abs() > 0.01) return SaleMismatch(difference);
    return null;
  }
}
