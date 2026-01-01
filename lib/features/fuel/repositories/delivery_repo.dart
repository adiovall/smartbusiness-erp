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

  /// ✅ REQUIRED: persist credit/debt adjustments (important for credit consumption)
  Future<void> update(DeliveryRecord d) async {
    final db = await AppDatabase.instance;

    await db.update(
      'deliveries',
      {
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
      where: 'id = ?',
      whereArgs: [d.id],
    );
  }

  Future<List<DeliveryRecord>> fetchAll() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('deliveries', orderBy: 'date DESC');
    return rows.map((r) => DeliveryRecord.fromJson(r)).toList();
  }

  Future<List<DeliveryRecord>> fetchToday() async {
    final db = await AppDatabase.instance;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final rows = await db.query(
      'deliveries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );

    return rows.map((r) => DeliveryRecord.fromJson(r)).toList();
  }

  /// ✅ For tracking screens (Analytics / History)
  Future<List<DeliveryRecord>> fetchByDateRange(DateTime from, DateTime to) async {
    final db = await AppDatabase.instance;

    final start = DateTime(from.year, from.month, from.day).toIso8601String();
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59).toIso8601String();

    final rows = await db.query(
      'deliveries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );

    return rows.map((r) => DeliveryRecord.fromJson(r)).toList();
  }

  /// ✅ Supplier memory from BOTH deliveries + settlements
  /// (so typing "M" suggests "Micheal" if it exists)
  ///
  /// - returns up to [limit] names
  /// - returns [] when query is empty (prevents dropdown showing all names)
  Future<List<String>> supplierSuggestions(String query, {int limit = 12}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final db = await AppDatabase.instance;

    // DISTINCT suppliers from deliveries + settlements
    final rows = await db.rawQuery(
      '''
      SELECT supplier FROM (
        SELECT DISTINCT supplier FROM deliveries
        UNION
        SELECT DISTINCT supplier FROM settlements
      )
      WHERE LOWER(supplier) LIKE ?
      ORDER BY supplier ASC
      LIMIT ?
      ''',
      ['%$q%', limit],
    );

    return rows.map((r) => (r['supplier'] as String)).toList();
  }

  /// ✅ Optional: all suppliers cache (fast local filtering)
  Future<List<String>> fetchAllSuppliersDistinct({int limit = 500}) async {
    final db = await AppDatabase.instance;

    final rows = await db.rawQuery(
      '''
      SELECT supplier FROM (
        SELECT DISTINCT supplier FROM deliveries
        UNION
        SELECT DISTINCT supplier FROM settlements
      )
      ORDER BY supplier ASC
      LIMIT ?
      ''',
      [limit],
    );

    return rows.map((r) => (r['supplier'] as String)).toList();
  }
}
