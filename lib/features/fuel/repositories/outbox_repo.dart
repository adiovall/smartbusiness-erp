// lib/features/fuel/repositories/outbox_repo.dart

import 'package:sqflite/sqflite.dart';
import '../../../core/db/app_database.dart';
import '../../../core/models/outbox_record.dart';

class OutboxRepo {
  Future<void> insert(OutboxRecord o) async {
    final db = await AppDatabase.instance;
    await db.insert('outbox', o.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<OutboxRecord>> fetchAll() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('outbox', orderBy: 'createdAt DESC');
    return rows.map(OutboxRecord.fromJson).toList();
  }

  Future<OutboxRecord?> fetchByBusinessDate(String businessDate) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'outbox',
      where: 'businessDate = ?',
      whereArgs: [businessDate],
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return OutboxRecord.fromJson(rows.first);
  }

  Future<List<OutboxRecord>> fetchUnsynced() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'outbox',
      where: 'synced = 0',
      orderBy: 'createdAt ASC',
    );
    return rows.map(OutboxRecord.fromJson).toList();
  }

  Future<void> markSynced(String id) async {
    final db = await AppDatabase.instance;
    await db.update('outbox', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }
}