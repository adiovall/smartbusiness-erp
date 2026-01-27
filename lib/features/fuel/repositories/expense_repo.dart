//lib/features/fuel/repositories/expense_repo.dart
import 'package:sqflite/sqflite.dart';
import '../../../core/db/app_database.dart';
import '../../../core/models/expense_record.dart';

class ExpenseRepo {
  Future<void> insert(ExpenseRecord e) async {
    final db = await AppDatabase.instance;
    await db.insert('expenses', e.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(ExpenseRecord e) async {
    final db = await AppDatabase.instance;
    await db.update('expenses', e.toJson(), where: 'id = ?', whereArgs: [e.id]);
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ExpenseRecord>> fetchAll() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('expenses', orderBy: 'date DESC');
    return rows.map((e) => ExpenseRecord.fromJson(e)).toList();
  }

  Future<List<ExpenseRecord>> fetchToday() async {
    final db = await AppDatabase.instance;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final rows = await db.query(
      'expenses',
      where: 'date BETWEEN ? AND ? AND isArchived = 0',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );

    return rows.map((e) => ExpenseRecord.fromJson(e)).toList();
  }

  Future<List<ExpenseRecord>> fetchTodayDrafts() async {
    final db = await AppDatabase.instance;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final rows = await db.query(
      'expenses',
      where: 'date BETWEEN ? AND ? AND isSubmitted = 0 AND isLocked = 0 AND isArchived = 0',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );

    return rows.map((e) => ExpenseRecord.fromJson(e)).toList();
  }

  Future<void> markSubmittedByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await AppDatabase.instance;

    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE expenses SET isSubmitted = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  Future<void> markSubmittedToday() async {
    final db = await AppDatabase.instance;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    await db.update(
      'expenses',
      {'isSubmitted': 1},
      where: 'date BETWEEN ? AND ? AND isSubmitted = 0 AND isArchived = 0',
      whereArgs: [start, end],
    );
  }


  Future<void> archiveTodayExpenses() async {
    final db = await AppDatabase.instance;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    await db.update(
      'expenses',
      {'isArchived': 1},
      where: 'date BETWEEN ? AND ? AND isArchived = 0 AND isSubmitted = 1',
      whereArgs: [start, end],
    );
  }


  Future<void> deleteDraftsToday() async {
    final db = await AppDatabase.instance;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    await db.delete(
      'expenses',
      where: 'date BETWEEN ? AND ? AND isSubmitted = 0 AND isLocked = 0 AND isArchived = 0',
      whereArgs: [start, end],
    );
  }

    Future<List<ExpenseRecord>> fetchAllTodayExpenses() async {
    final db = await AppDatabase.instance;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final rows = await db.query(
      'expenses',
      where: 'date BETWEEN ? AND ? AND isArchived = 0',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );

    return rows.map((e) => ExpenseRecord.fromJson(e)).toList();
  }


  Future<double> getTodayExpenseTotalForCalculation() async {
    final db = await AppDatabase.instance;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final result = await db.rawQuery(
    'SELECT SUM(amount) as total FROM expenses WHERE date BETWEEN ? AND ? AND isArchived = 0',
    [start, end],
  );
  return (result.first['total'] as num?)?.toDouble() ?? 0.0;

  }
}