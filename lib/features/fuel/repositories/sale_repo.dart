// lib/features/fuel/repositories/sale_repo.dart

import 'package:sqflite/sqflite.dart';
import '../../../core/db/app_database.dart';
import '../../../core/models/sale_record.dart';

class SaleRepo {
  Future<void> insert(SaleRecord sale) async {
    final db = await AppDatabase.instance;
    await db.insert(
      'sales',
      sale.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SaleRecord>> fetchToday() async {
    final db = await AppDatabase.instance;

    final todayStr = DateTime.now().toIso8601String().substring(0, 10); // yyyy-MM-dd

    final rows = await db.query(
      'sales',
      where: "substr(date, 1, 10) = ? AND isArchived = 0",
      whereArgs: [todayStr],
      orderBy: 'date DESC',
    );

    return rows.map(SaleRecord.fromJson).toList();
  }

  Future<List<SaleRecord>> fetchAll() async {
    final db = await AppDatabase.instance;

    final rows = await db.query(
      'sales',
      orderBy: 'date DESC',
    );

    return rows.map(SaleRecord.fromJson).toList();
  }

  Future<void> updateBusinessDate(String oldDate, String newDate) async {
    final db = await AppDatabase.instance;
    await db.update(
      'sales',
      {'businessDate': newDate},
      where: 'businessDate = ?',
      whereArgs: [oldDate],
    );
  }

  Future<double> getTodayTotalAmount() async {
    final sales = await fetchToday();
    double total = 0.0;
    for (final sale in sales) {
      total += sale.totalAmount;
    }
    return total;
  }

  /// ✅ FIXED: accurate SUM for today (works with milliseconds too)
  Future<double> fetchTodayTotalAmount() async {
    final db = await AppDatabase.instance;

    final todayStr = DateTime.now().toIso8601String().substring(0, 10); // yyyy-MM-dd

    final rows = await db.rawQuery(
      'SELECT SUM(totalAmount) AS total FROM sales WHERE substr(date,1,10) = ? AND isArchived = 0',
      [todayStr],
    );

    final v = rows.first['total'];
    if (v == null) return 0.0;
    return (v as num).toDouble();
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance;
    await db.delete(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAll() async {
    final db = await AppDatabase.instance;
    await db.delete('sales');
  }

  // Add to sale_repo.dart:

  Future<List<SaleRecord>> fetchAllForBusinessDate(String businessDate) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'sales',
      where: 'businessDate = ?',
      whereArgs: [businessDate],
      orderBy: 'date DESC',
    );
    return rows.map(SaleRecord.fromJson).toList();
  }

  Future<void> archiveForBusinessDate(String businessDate) async {
    final db = await AppDatabase.instance;
    await db.update(
      'sales',
      {'isArchived': 1},
      where: 'businessDate = ?',
      whereArgs: [businessDate],
    );
  }

  Future<void> update(SaleRecord sale) async {
    final db = await AppDatabase.instance;
    await db.update('sales', sale.toJson(), where: 'id = ?', whereArgs: [sale.id]);
  }

  Future<List<SaleRecord>> fetchTodayDrafts() async {
    final db = await AppDatabase.instance;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    final rows = await db.query(
      'sales',
      where: "substr(date, 1, 10) = ? AND isSubmitted = 0 AND isArchived = 0",
      whereArgs: [todayStr],
      orderBy: 'date DESC',
    );

    return rows.map(SaleRecord.fromJson).toList();
  }

  Future<void> markSubmittedByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await AppDatabase.instance;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE sales SET isSubmitted = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  Future<int> countTodaySubmitted() async {
    final db = await AppDatabase.instance;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sales WHERE substr(date,1,10) = ? AND isSubmitted = 1 AND isArchived = 0',
      [todayStr],
    );
    return (result.first['count'] as int?) ?? 0;
  }

}
