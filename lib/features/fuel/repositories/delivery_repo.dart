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
        'salesPaid': d.salesPaid,
        'externalPaid': d.externalPaid,
        'creditUsed': d.creditUsed,
        'source': d.source,
        'debt': d.debt,
        'credit': d.credit,
        'creditInitial': d.creditInitial, // ✅ add
        'isSubmitted': d.isSubmitted,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

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
        'salesPaid': d.salesPaid,
        'externalPaid': d.externalPaid,
        'creditUsed': d.creditUsed,
        'source': d.source,
        'debt': d.debt,
        'credit': d.credit,
        'creditInitial': d.creditInitial, // ✅ add
        'isSubmitted': d.isSubmitted,
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

  Future<List<DeliveryRecord>> fetchTodayDraft() async {
    final db = await AppDatabase.instance;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final rows = await db.query(
      'deliveries',
      where: 'date BETWEEN ? AND ? AND isSubmitted = 0',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );

    return rows.map((r) => DeliveryRecord.fromJson(r)).toList();
  }

  Future<List<DeliveryRecord>> fetchTodaySubmitted() async {
    final db = await AppDatabase.instance;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final rows = await db.query(
      'deliveries',
      where: 'date BETWEEN ? AND ? AND isSubmitted = 1',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );

    return rows.map((r) => DeliveryRecord.fromJson(r)).toList();
  }

  Future<void> deleteById(String id) async {
    final db = await AppDatabase.instance;
    await db.delete('deliveries', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markSubmittedByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await AppDatabase.instance;

    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE deliveries SET isSubmitted = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  /// ✅ Supplier memory from BOTH deliveries + settlements
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

