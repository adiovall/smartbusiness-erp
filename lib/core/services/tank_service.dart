// lib/core/services/tank_service.dart

import '../models/tank_state.dart';
import '../../features/fuel/repositories/tank_repo.dart';

class TankService {
  final TankRepo repo;
  final Map<String, TankState> _tanks = {};

  TankService(this.repo);

  /// Load tanks from DB on startup
  Future<void> loadFromDb() async {
    final rows = await repo.fetchAll();
    _tanks.clear();

    for (final t in rows) {
      _tanks[t.fuelType] = t;
    }
  }

  void addFuel(String fuelType, double liters) {
    final tank = _tanks[fuelType];
    if (tank == null) return;

    tank.addFuel(liters);
    repo.save(tank);
  }

  void removeFuel(String fuelType, double liters) {
    final tank = _tanks[fuelType];
    if (tank == null) return;

    tank.removeFuel(liters);
    repo.save(tank);
  }

  List<TankState> get allTanks =>
      _tanks.values.toList();
}
