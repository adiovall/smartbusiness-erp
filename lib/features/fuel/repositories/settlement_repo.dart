// lib/features/fuel/repositories/settlement_repo.dart

import 'package:sqflite/sqflite.dart';
import '../../../core/db/app_database.dart';
import '../../../core/models/settlement_record.dart';

class SettlementRepo {
  Future<void> insert(SettlementRecord r) async {
    final db = await AppDatabase.instance;
    await db.insert(
      'settlements',
      r.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SettlementRecord>> fetchToday() async {
    final db = await AppDatabase.instance;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final rows = await db.query(
      'settlements',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );

    return rows.map(SettlementRecord.fromJson).toList();
  }

  Future<List<SettlementRecord>> fetchAll() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('settlements', orderBy: 'date DESC');
    return rows.map(SettlementRecord.fromJson).toList();
  }
}
