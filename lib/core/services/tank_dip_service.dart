// lib/core/services/tank_dip_service.dart

import '../models/tank_dip_record.dart';
import '../../features/fuel/repositories/tank_dip_repo.dart';

class TankDipService {
  final TankDipRepo repo;

  List<TankDipRecord> _todayDrafts = [];
  List<TankDipRecord> get todayDrafts => _todayDrafts;

  TankDipService({required this.repo});

  Future<List<TankDipRecord>> allForBusinessDate(String businessDate) async {
    final drafts = await repo.fetchAllForBusinessDate(businessDate);
    _todayDrafts = drafts;
    return drafts;
  }

  Future<void> saveDraft(TankDipRecord record) async {
    await repo.insert(record);
    final idx = _todayDrafts.indexWhere((d) => d.fuelType == record.fuelType);
    if (idx != -1) {
      _todayDrafts[idx] = record;
    } else {
      _todayDrafts.add(record);
    }
  }

  Future<void> archiveForBusinessDate(String businessDate) async {
    await repo.archiveForBusinessDate(businessDate);
    _todayDrafts = _todayDrafts.where((d) => d.businessDate != businessDate).toList();
  }

  Future<void> delete(String id) async {
    await repo.delete(id);
    _todayDrafts.removeWhere((d) => d.id == id);
  }

  Future<int> countForBusinessDate(String businessDate) =>
      repo.countForBusinessDate(businessDate);

  Future<int> countSubmittedForBusinessDate(String businessDate) =>
      repo.countSubmittedForBusinessDate(businessDate);

  List<TankDipRecord> generateDrafts({
    required String businessDate,
    required List<String> fuelTypes,
  }) {
    return fuelTypes.map((fuel) => TankDipRecord(
      id: '${DateTime.now().millisecondsSinceEpoch}_$fuel',
      businessDate: businessDate,
      fuelType: fuel,
      openingLevel: 0.0,
      closingLevel: 0.0,
      createdAt: DateTime.now(),
    )).toList();
  }
}