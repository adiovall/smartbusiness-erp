// lib/core/models/tank_state.dart

class TankState {
  final String fuelType;
  final double capacity;
  double currentLevel;

  TankState({
    required this.fuelType,
    required this.capacity,
    required this.currentLevel,
  });

  double get percentage =>
      capacity == 0 ? 0 : (currentLevel / capacity) * 100;

  void addFuel(double liters) {
    currentLevel += liters;
    if (currentLevel > capacity) {
      currentLevel = capacity;
    }
  }

  void removeFuel(double liters) {
    currentLevel -= liters;
    if (currentLevel < 0) {
      currentLevel = 0;
    }
  }

  Map<String, dynamic> toJson() => {
        'fuelType': fuelType,
        'capacity': capacity,
        'currentLevel': currentLevel,
        'percentage': percentage,
      };
}
