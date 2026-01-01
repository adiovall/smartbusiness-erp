import 'package:temp_fuel_app/core/services/service_registry.dart';
import 'fuel_mapping.dart';

/// Note: keep PumpSale inside SaleTab for now.
/// We'll accept it here via dynamic typing to avoid circular imports.
/// Later you can move PumpSale to domain too.
class SaleDraftEngine {
  static double virtualConsumed({
    required List<dynamic> recorded,
    required String tankKey,
    int? excludeIndex,
  }) {
    double sum = 0.0;
    for (int i = 0; i < recorded.length; i++) {
      if (excludeIndex != null && i == excludeIndex) continue;
      final p = recorded[i];
      final key = FuelMapping.tankKey(p.fuel as String);
      if (key == tankKey) sum += (p.liters as double);
    }
    return sum;
  }

  static double availableLiters({
    required String selectedFuelLabel,
    required List<dynamic> recorded,
    int? editingIndex,
  }) {
    final tankKey = FuelMapping.tankKey(selectedFuelLabel);
    final tank = Services.tank.getTank(tankKey);

    final base = tank?.currentLevel ?? 0.0;
    final consumed = virtualConsumed(
      recorded: recorded,
      tankKey: tankKey,
      excludeIndex: editingIndex,
    );

    return (base - consumed).clamp(0.0, double.infinity).toDouble();
  }

  static Future<void> applyTankConsumption(List<dynamic> recorded) async {
    final Map<String, double> consumption = {};

    for (final sale in recorded) {
      final key = FuelMapping.tankKey(sale.fuel as String);
      consumption[key] = (consumption[key] ?? 0.0) + (sale.liters as double);
    }

    for (final entry in consumption.entries) {
      await Services.tank.removeFuel(entry.key, entry.value);
    }
  }
}
