import 'package:flutter/foundation.dart';
import '../models/pump_config_record.dart';
import '../../features/fuel/repositories/pump_config_repo.dart';

class PumpConfigService with ChangeNotifier {
  final PumpConfigRepo repo;
  PumpConfigService({required this.repo});

  List<PumpConfigRecord> _pumps = [];
  List<PumpConfigRecord> get pumps => List.unmodifiable(_pumps);

  Future<void> loadFromDb() async {
    _pumps = await repo.fetchAll();
    notifyListeners();
  }

  /// Pump numbers (as plain strings, e.g. "1", "2") assigned to a given
  /// fuel type abbreviation, sorted numerically.
  List<String> pumpNumbersForFuel(String fuelType) {
    final matches = _pumps.where((p) => p.fuelType == fuelType).toList();
    matches.sort((a, b) =>
        (int.tryParse(a.pumpNo) ?? 0).compareTo(int.tryParse(b.pumpNo) ?? 0));
    return matches.map((p) => p.pumpNo).toList();
  }

  String? fuelTypeForPump(String pumpNo) {
    final match = _pumps.where((p) => p.pumpNo == pumpNo);
    return match.isEmpty ? null : match.first.fuelType;
  }

  /// Saves a full pump configuration in one atomic write. Called by the
  /// settings dialog on Save — count and per-pump fuel assignments are
  /// always persisted together, never partially.
  Future<void> saveConfig(Map<String, String> pumpNoToFuel) async {
    final records = pumpNoToFuel.entries
        .map((e) => PumpConfigRecord(pumpNo: e.key, fuelType: e.value))
        .toList();
    records.sort((a, b) =>
        (int.tryParse(a.pumpNo) ?? 0).compareTo(int.tryParse(b.pumpNo) ?? 0));
    await repo.replaceAll(records);
    _pumps = records;
    notifyListeners();
  }
}