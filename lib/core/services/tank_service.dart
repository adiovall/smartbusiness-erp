// lib/core/services/tank_service.dart

import 'package:flutter/foundation.dart'; // ← ADD THIS
import '../models/tank_state.dart';
import '../../features/fuel/repositories/tank_repo.dart';

class TankService with ChangeNotifier {
  final TankRepo repo;
  final Map<String, TankState> _tanks = {};

  TankService(this.repo);

  /// Load tanks from DB on startup + create defaults if empty
  Future<void> loadFromDb() async {
    final rows = await repo.fetchAll();
    _tanks.clear();

    for (final t in rows) {
      _tanks[t.fuelType] = t;
    }

    // Create default tanks if none exist
    if (_tanks.isEmpty) {
      final defaults = [
        TankState(fuelType: 'PMS', capacity: 33000, currentLevel: 18000),
        TankState(fuelType: 'AGO', capacity: 33000, currentLevel: 20000),
        TankState(fuelType: 'DPK', capacity: 20000, currentLevel: 5000),
        TankState(fuelType: 'Gas', capacity: 10000, currentLevel: 3800),
      ];

      for (final tank in defaults) {
        _tanks[tank.fuelType] = tank;
        await repo.save(tank);
      }
    }

    notifyListeners(); // Trigger rebuild in UI
  }

  /// Update tank and save to DB
  Future<void> updateTank(TankState updatedTank) async {
    _tanks[updatedTank.fuelType] = updatedTank;
    await repo.save(updatedTank);
    notifyListeners(); // This will rebuild TankLevelsPerfect automatically
  }

  /// Helper methods
  TankState? getTank(String fuelType) => _tanks[fuelType];

  bool hasEnoughFuel(String fuelType, double liters) {
    final tank = getTank(fuelType);
    return tank != null && tank.currentLevel >= liters;
  }

  Future<void> addFuel(String fuelType, double liters) async {
    final tank = getTank(fuelType);
    if (tank == null) return;
    tank.addFuel(liters);
    await updateTank(tank);
  }

  Future<void> removeFuel(String fuelType, double liters) async {
    final tank = getTank(fuelType);
    if (tank == null) return;
    tank.removeFuel(liters);
    await updateTank(tank);
  }

  List<TankState> get allTanks => _tanks.values.toList();
}