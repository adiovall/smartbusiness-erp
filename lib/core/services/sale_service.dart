// lib/features/fuel/services/sale_service.dart

import 'dart:math';
import '../models/sale_record.dart';
import '../../features/fuel/repositories/sale_repo.dart';
import 'tank_service.dart';

class SaleMismatch {
  final double difference;
  SaleMismatch(this.difference);
}

class SaleService {
  final TankService tankService;
  final SaleRepo saleRepo;

  /// Temporary (unsubmitted) pump records
  final List<SaleRecord> _draftSales = [];

  /// Committed sales
  final List<SaleRecord> _sales = [];

  SaleService({
    required this.tankService,
    required this.saleRepo,
  });

  /// Record ONE pump (DRAFT only)
  SaleRecord recordSale({
    required String pumpNo,
    required String fuelType,
    required double opening,
    required double closing,
    required double unitPrice,
  }) {
    final liters = max(0.0, closing - opening);

    if (liters <= 0) {
      throw Exception('Invalid meter readings');
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

  /// 🔍 Check mismatch BEFORE final submit
  SaleMismatch? checkMismatch({
    required double cash,
    required double pos,
  }) {
    final totalSold =
        _draftSales.fold(0.0, (sum, s) => sum + s.totalAmount);

    final received = cash + pos;
    final diff = totalSold - received;

    if (diff != 0) {
      return SaleMismatch(diff);
    }
    return null;
  }

  /// ✅ FINAL SUBMIT (commit + persist)
  Future<void> submitSales() async {
    for (final sale in _draftSales) {
      tankService.removeFuel(sale.fuelType, sale.liters);
      _sales.add(sale);
      await saleRepo.insert(sale);
    }
    _draftSales.clear();
  }

  /// ❌ Undo draft sales
  void undoDraft() {
    _draftSales.clear();
  }

  List<SaleRecord> get draftSales =>
      List.unmodifiable(_draftSales);

  List<SaleRecord> get todaySales =>
      _sales.where((s) => _isToday(s.date)).toList();

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year &&
        d.month == now.month &&
        d.day == now.day;
  }
}
