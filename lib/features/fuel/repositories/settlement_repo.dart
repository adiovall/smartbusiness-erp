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

  Future<void> updateBusinessDate(String oldDate, String newDate) async {
    final db = await AppDatabase.instance;
    await db.update(
      'settlements',
      {'businessDate': newDate},
      where: 'businessDate = ?',
      whereArgs: [oldDate],
    );
  }

  Future<List<SettlementRecord>> fetchAll() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('settlements', orderBy: 'date DESC');
    return rows.map(SettlementRecord.fromJson).toList();
  }

  Future<List<SettlementRecord>> fetchAllForBusinessDate(String businessDate) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'settlements',
      where: 'businessDate = ?',
      whereArgs: [businessDate],
      orderBy: 'date DESC',
    );
    return rows.map(SettlementRecord.fromJson).toList();
  }

  Future<int> countTodayPending(bool todayAlreadySent) async {
    if (todayAlreadySent) return 0;

    final db = await AppDatabase.instance;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM settlements WHERE date BETWEEN ? AND ?',
      [start, end],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> countPendingForBusinessDate(String businessDate, bool alreadySent) async {
    if (alreadySent) return 0;

    final db = await AppDatabase.instance;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM settlements WHERE businessDate = ?',
      [businessDate],
    );
    return (result.first['count'] as int?) ?? 0;
  }
}
