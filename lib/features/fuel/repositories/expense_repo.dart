// lib/features/fuel/repositories/expense_repo.dart

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

  Future<List<ExpenseRecord>> fetchAll() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('expenses');
    return rows.map((e) => ExpenseRecord.fromJson(e)).toList();
  }

  Future<List<ExpenseRecord>> fetchToday() async {
    final db = await AppDatabase.instance;

    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).toIso8601String();

    final rows = await db.query(
      'expenses',
      where: 'date >= ?',
      whereArgs: [start],
    );

    return rows.map((e) => ExpenseRecord.fromJson(e)).toList();
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }
}



  

  
