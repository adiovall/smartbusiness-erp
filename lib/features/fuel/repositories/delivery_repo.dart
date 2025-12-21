// lib/features/fuel/repositories/delivery_repo.dart

import 'package:sqflite/sqflite.dart';
import '../../../core/db/app_database.dart';
import '../../../core/models/delivery_record.dart';

class DeliveryRepo {
  Future<void> insert(DeliveryRecord d) async {
    final db = await AppDatabase.instance;

    await db.insert(
      'deliveries',
      {
        'id': d.id,
        'date': d.date.toIso8601String(),
        'supplier': d.supplier,
        'fuelType': d.fuelType,
        'liters': d.liters,
        'totalCost': d.totalCost,
        'amountPaid': d.amountPaid,
        'source': d.source,
        'debt': d.debt,
        'credit': d.credit,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// ✅ REQUIRED
  Future<List<DeliveryRecord>> fetchAll() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('deliveries', orderBy: 'date DESC');
    return rows.map((r) => DeliveryRecord.fromJson(r)).toList();
  }

  /// ✅ OPTIONAL (nice for UI)
  Future<List<DeliveryRecord>> fetchToday() async {
    final db = await AppDatabase.instance;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59)
        .toIso8601String();

    final rows = await db.query(
      'deliveries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );

    return rows.map((r) => DeliveryRecord.fromJson(r)).toList();
  }
}
