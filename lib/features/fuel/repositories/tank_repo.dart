
// lib/features/fuel/repositories/tank_repo.dart

import 'package:sqflite/sqflite.dart';
import '../../../core/db/app_database.dart';
import '../../../core/models/tank_state.dart';

class TankRepo {
  Future<void> save(TankState t) async {
    final db = await AppDatabase.instance;

    await db.insert(
      'tanks',
      {
        'fuelType': t.fuelType,
        'capacity': t.capacity,
        'currentLevel': t.currentLevel,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// ✅ REQUIRED
  Future<List<TankState>> fetchAll() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('tanks');

    return rows.map((r) {
      return TankState(
        fuelType: r['fuelType'] as String,
        capacity: (r['capacity'] as num).toDouble(),
        currentLevel: (r['currentLevel'] as num).toDouble(),
      );
    }).toList();
  }
}
