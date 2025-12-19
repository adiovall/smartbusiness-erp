
// lib/features/fuel/repositories/debt_repo.dart
import 'package:sqflite/sqflite.dart';
import '../../../core/db/app_database.dart';
import '../../../core/models/debt_record.dart';

class DebtRepo {
  Future<void> insert(DebtRecord d) async {
    final db = await AppDatabase.instance;

    await db.insert(
      'debts',
      {
        'id': d.id,
        'supplier': d.supplier,
        'fuelType': d.fuelType,
        'amount': d.amount,
        'createdAt': d.createdAt.toIso8601String(),
        'settled': d.settled ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(DebtRecord d) async {
    final db = await AppDatabase.instance;

    await db.update(
      'debts',
      {
        'amount': d.amount,
        'settled': d.settled ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [d.id],
    );
  }
}

