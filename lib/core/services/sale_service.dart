// lib/core/services/sale_service.dart

import 'dart:math';
import '../../core/models/sale_record.dart'; // Adjust path if needed
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

  /// In-memory draft sales (current batch, not submitted yet)
  final List<SaleRecord> _draftSales = [];

  /// All committed sales loaded from DB (optional — only if you load history)
  final List<SaleRecord> _committedSales = [];

  SaleService({
    required this.tankService,
    required this.saleRepo,
  });

  /// Record a single pump sale into draft
  /// Called from SaleTab when user presses "Record Pump"
  SaleRecord recordDraftSale({
    required String pumpNo,
    required String fuelType,
    required double opening,
    required double closing,
    required double unitPrice,
  }) {
    final liters = max(0.0, closing - opening);

    if (liters <= 0) {
      throw Exception('Closing meter must be greater than opening');
    }

    if (unitPrice <= 0) {
      throw Exception('Unit price must be greater than zero');
    }

    // Optional: check tank here too (extra safety)
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

    // Immediately deduct from tank (matches your UI behavior)
    tankService.removeFuel(fuelType, liters);

    return sale;
  }

  /// Check for mismatch between total sold and money received
  SaleMismatch? checkMismatch({
    required double cashReceived,
    required double posReceived,
  }) {
    final totalSold = getDraftTotalAmount();
    final totalReceived = cashReceived + posReceived;
    final difference = totalSold - totalReceived;

    if (difference.abs() > 0.01) { // tolerate floating point
      return SaleMismatch(difference);
    }
    return null;
  }

  /// Final submit: persist to DB and clear draft
  Future<void> submitBatch() async {
    if (_draftSales.isEmpty) return;

    for (final sale in _draftSales) {
      await saleRepo.insert(sale);
      _committedSales.add(sale);
    }

    _draftSales.clear();
  }

  Future<double> todayTotalAmount() async {
    return await saleRepo.fetchTodayTotalAmount();
  }


  /// Undo all draft sales and return fuel to tanks
  void undoAllDraft() {
    for (final sale in _draftSales) {
      tankService.addFuel(sale.fuelType, sale.liters);
    }
    _draftSales.clear();
  }

  /// Delete single draft sale (used when deleting a pump row)
  void deleteDraftSale(SaleRecord sale) {
    _draftSales.remove(sale);
    tankService.addFuel(sale.fuelType, sale.liters);
  }

  /// Get current draft total
  double getDraftTotalAmount() {
    return _draftSales.fold(0.0, (sum, s) => sum + s.totalAmount);
  }

  int get draftCount => _draftSales.length;

  /// Get today's total sales amount (from committed only — or load from repo if needed)
  List<SaleRecord> get draftSales => List.unmodifiable(_draftSales);

  bool get hasDraft => _draftSales.isNotEmpty;
}