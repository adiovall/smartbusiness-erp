


//lib/features/fuel/repositories/tank_repo.dart
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
}
