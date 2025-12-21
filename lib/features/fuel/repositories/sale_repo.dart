// lib/features/fuel/repositories/sale_repo.dart

import 'package:sqflite/sqflite.dart';
import '../../../core/db/app_database.dart';
import '../../../core/models/sale_record.dart';

class SaleRepo {
  Future<void> insert(SaleRecord s) async {
    final db = await AppDatabase.instance;
    await db.insert('sales', s.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// ✅ Better: true today filter
  Future<List<SaleRecord>> fetchToday() async {
    final db = await AppDatabase.instance;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end =
        DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final rows = await db.query(
      'sales',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );

    return rows.map((r) => SaleRecord(
      id: r['id'] as String,
      date: DateTime.parse(r['date'] as String),
      pumpNo: r['pumpNo'] as String,
      fuelType: r['fuelType'] as String,
      liters: (r['liters'] as num).toDouble(),
      unitPrice: (r['unitPrice'] as num).toDouble(),
    )).toList();
  }

  /// ✅ REQUIRED for Service loading
  Future<List<SaleRecord>> fetchAll() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('sales', orderBy: 'date DESC');
    return rows.map((r) => SaleRecord(
      id: r['id'] as String,
      date: DateTime.parse(r['date'] as String),
      pumpNo: r['pumpNo'] as String,
      fuelType: r['fuelType'] as String,
      liters: (r['liters'] as num).toDouble(),
      unitPrice: (r['unitPrice'] as num).toDouble(),
    )).toList();
  }
}
