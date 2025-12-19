import '../models/tank_state.dart';

class TankService {
  final Map<String, TankState> _tanks = {};

  /// Register a tank (call once at startup)
  void registerTank(TankState tank) {
    _tanks[tank.fuelType] = tank;
  }

  /// Get tank by fuel type
  TankState getTank(String fuelType) {
    final tank = _tanks[fuelType];
    if (tank == null) {
      throw Exception('Tank not registered for $fuelType');
    }
    return tank;
  }

  /// Add fuel (Delivery)
  void addFuel(String fuelType, double liters) {
    final tank = getTank(fuelType);
    tank.addFuel(liters);
  }

  /// Remove fuel (Sale)
  void removeFuel(String fuelType, double liters) {
    final tank = getTank(fuelType);
    tank.removeFuel(liters);
  }

  /// For analytics / UI
  List<TankState> get allTanks => _tanks.values.toList();
}
