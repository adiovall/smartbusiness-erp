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
      where: "substr(date, 1, 10) = ?",
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
      'SELECT SUM(totalAmount) AS total FROM sales WHERE substr(date,1,10) = ?',
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
}
