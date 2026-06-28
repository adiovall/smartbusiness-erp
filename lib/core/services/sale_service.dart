// lib/core/services/sale_service.dart

import 'package:flutter/foundation.dart';
import '../models/sale_record.dart';
import '../../features/fuel/repositories/sale_repo.dart';
import 'tank_service.dart';

class SaleMismatch {
  final double difference;
  final bool isShortage;

  SaleMismatch(this.difference) : isShortage = difference > 0;

  double get absolute => difference.abs();
}

class SaleService with ChangeNotifier {
  final TankService tankService;
  final SaleRepo saleRepo;

  final List<SaleRecord> _sales = [];

  SaleService({
    required this.tankService,
    required this.saleRepo,
  });

  List<SaleRecord> get all => List.unmodifiable(_sales);

  Future<void> loadFromDb() async {
    final rows = await saleRepo.fetchAll();
    _sales
      ..clear()
      ..addAll(rows);
    notifyListeners();
  }

  Future<void> refreshToday() async {
    final rows = await saleRepo.fetchToday();

    final now = DateTime.now();
    _sales.removeWhere((s) =>
        s.date.year == now.year &&
        s.date.month == now.month &&
        s.date.day == now.day);

    _sales.addAll(rows);
    notifyListeners();
  }

  List<SaleRecord> get todayAllVisible {
    final t = DateTime.now();
    final list = _sales
        .where((s) =>
            s.date.year == t.year &&
            s.date.month == t.month &&
            s.date.day == t.day &&
            !s.isArchived)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<SaleRecord> get todayDrafts {
    final t = DateTime.now();
    final list = _sales
        .where((s) =>
            s.date.year == t.year &&
            s.date.month == t.month &&
            s.date.day == t.day &&
            !s.isArchived &&
            !s.isSubmitted)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<SaleRecord> recordDraftSale({
    required String pumpNo,
    required String fuelType,
    required double opening,
    required double closing,
    required double unitPrice,
  }) async {
    final liters = closing - opening;

    if (liters <= 0) throw Exception('Closing meter must be greater than opening');
    if (unitPrice <= 0) throw Exception('Unit price must be greater than zero');

    final tank = tankService.getTank(fuelType);
    if (tank != null && liters > tank.currentLevel) {
      throw Exception('Not enough fuel in $fuelType tank (${tank.currentLevel}L available)');
    }

    await tankService.removeFuel(fuelType, liters);

    final sale = SaleRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      pumpNo: pumpNo,
      fuelType: fuelType,
      opening: opening,
      closing: closing,
      liters: liters,
      unitPrice: unitPrice,
      isSubmitted: false,
      isArchived: false,
    );

    _sales.add(sale);
    await saleRepo.insert(sale);
    notifyListeners();
    return sale;
  }

  Future<SaleRecord> editDraftSale({
    required String id,
    required String pumpNo,
    required String fuelType,
    required double opening,
    required double closing,
    required double unitPrice,
  }) async {
    final old = _sales.firstWhere((s) => s.id == id);

    if (old.isSubmitted) {
      throw Exception('Cannot edit after submit');
    }

    final newLiters = closing - opening;
    if (newLiters <= 0) throw Exception('Closing meter must be greater than opening');
    if (unitPrice <= 0) throw Exception('Unit price must be greater than zero');

    if (fuelType != old.fuelType) {
      await tankService.addFuel(old.fuelType, old.liters);
      final tank = tankService.getTank(fuelType);
      if (tank != null && newLiters > tank.currentLevel) {
        await tankService.removeFuel(old.fuelType, old.liters);
        throw Exception('Not enough fuel in $fuelType tank (${tank.currentLevel}L available)');
      }
      await tankService.removeFuel(fuelType, newLiters);
    } else {
      final delta = newLiters - old.liters;
      if (delta > 0) {
        final tank = tankService.getTank(fuelType);
        if (tank != null && delta > tank.currentLevel) {
          throw Exception('Not enough fuel in $fuelType tank (${tank.currentLevel}L available)');
        }
        await tankService.removeFuel(fuelType, delta);
      } else if (delta < 0) {
        await tankService.addFuel(fuelType, -delta);
      }
    }

    final updated = old.copyWith(
      pumpNo: pumpNo,
      fuelType: fuelType,
      opening: opening,
      closing: closing,
      liters: newLiters,
      unitPrice: unitPrice,
    );

    final idx = _sales.indexWhere((s) => s.id == id);
    _sales[idx] = updated;

    await saleRepo.update(updated);
    notifyListeners();
    return updated;
  }

  Future<void> deleteDraftSale(String id) async {
    final s = _sales.firstWhere((x) => x.id == id);

    if (s.isSubmitted) {
      throw Exception('Cannot delete after submit');
    }

    if (s.liters > 0) {
      await tankService.addFuel(s.fuelType, s.liters);
    }

    _sales.removeWhere((x) => x.id == id);
    await saleRepo.delete(id);
    notifyListeners();
  }

  Future<void> submitDraftSales(List<SaleRecord> drafts) async {
    if (drafts.isEmpty) return;

    await saleRepo.markSubmittedByIds(drafts.map((s) => s.id).toList());

    for (final d in drafts) {
      final idx = _sales.indexWhere((x) => x.id == d.id);
      if (idx != -1) {
        _sales[idx] = _sales[idx].copyWith(isSubmitted: true);
      }
    }

    notifyListeners();
  }

  Future<void> moveBusinessDate(String oldDate, String newDate) async {
    await saleRepo.updateBusinessDate(oldDate, newDate);
  }

  Future<List<SaleRecord>> allForBusinessDate(String businessDate) async {
    return saleRepo.fetchAllForBusinessDate(businessDate);
  }

  Future<void> archiveForBusinessDate(String businessDate) async {
    await saleRepo.archiveForBusinessDate(businessDate);
  }

  Future<double> todayTotalAmount({bool includeDraft = false}) async {
    return saleRepo.fetchTodayTotalAmount();
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