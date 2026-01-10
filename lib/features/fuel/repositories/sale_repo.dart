// lib/features/fuel/repositories/sale_repo.dart

import 'package:sqflite/sqflite.dart';
import '../../../core/db/app_database.dart';
import '../../../core/models/sale_record.dart';

class SaleRepo {
  /// Insert or update a sale record
  Future<void> insert(SaleRecord sale) async {
    final db = await AppDatabase.instance;
    await db.insert(
      'sales',
      sale.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Fetch all sales for today only (most efficient & accurate)
  Future<List<SaleRecord>> fetchToday() async {
    final db = await AppDatabase.instance;

    final todayStr = DateTime.now().toIso8601String().substring(0, 10); // yyyy-MM-dd

    final rows = await db.query(
      'sales',
      where: "substr(date, 1, 10) = ?", // Compare only date part
      whereArgs: [todayStr],
      orderBy: 'date DESC',
    );

    return rows.map(SaleRecord.fromJson).toList();
  }

  /// Fetch all sales (for history/reporting)
  Future<List<SaleRecord>> fetchAll() async {
    final db = await AppDatabase.instance;

    final rows = await db.query(
      'sales',
      orderBy: 'date DESC',
    );

    return rows.map(SaleRecord.fromJson).toList();
  }

  /// Get total sales amount for today (used for main screen persistence)
  Future<double> getTodayTotalAmount() async {
    final sales = await fetchToday();
    double total = 0.0;
    for (final sale in sales) {
      total += sale.totalAmount;
    }
    return total;
  }

  /// Delete a sale (useful for undo or correction)
  Future<void> delete(String id) async {
    final db = await AppDatabase.instance;
    await db.delete(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  /// Optional: Clear all sales (for testing)
  Future<void> clearAll() async {
    final db = await AppDatabase.instance;
    await db.delete('sales');
  }

    Future<double> fetchTodayTotalAmount() async {
    final db = await AppDatabase.instance;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final rows = await db.rawQuery(
      'SELECT SUM(totalAmount) AS total FROM sales WHERE date BETWEEN ? AND ?',
      [start, end],
    );

    final v = rows.first['total'];
    if (v == null) return 0.0;
    return (v as num).toDouble();
  }

}


