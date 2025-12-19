//lib/features/fuel/repositories/expense_repo.dart

import 'package:sqflite/sqflite.dart';
import '../../../core/db/app_database.dart';
import '../../../core/models/expense_record.dart';

class ExpenseRepo {
  Future<void> insert(ExpenseRecord e) async {
    final db = await AppDatabase.instance;

    await db.insert(
      'expenses',
      e.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteByRef(String refId) async {
    final db = await AppDatabase.instance;
    await db.delete(
      'expenses',
      where: 'refId = ?',
      whereArgs: [refId],
    );
  }
}
