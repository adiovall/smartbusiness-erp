// lib/features/fuel/repositories/tank_dip_repo.dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../core/db/app_database.dart';
import '../../../core/models/tank_dip_record.dart';

class TankDipRepo {
  Future<void> insert(TankDipRecord record) async {
    final db = await AppDatabase.instance;
    await db.insert('tank_dips', record.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TankDipRecord>> fetchAllForBusinessDate(String businessDate) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'tank_dips',
      where: 'businessDate = ? AND isArchived = 0',
      whereArgs: [businessDate],
      orderBy: 'fuelType ASC',
    );
    return rows.map(TankDipRecord.fromJson).toList();
  }

  Future<List<TankDipRecord>> fetchAll() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('tank_dips', orderBy: 'businessDate DESC');
    return rows.map(TankDipRecord.fromJson).toList();
  }

  Future<void> archiveForBusinessDate(String businessDate) async {
    final db = await AppDatabase.instance;
    await db.update(
      'tank_dips',
      {'isArchived': 1, 'isSubmitted': 1},
      where: 'businessDate = ?',
      whereArgs: [businessDate],
    );
  }

  Future<int> countSubmittedForBusinessDate(String businessDate) async {
    final db = await AppDatabase.instance;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM tank_dips WHERE businessDate = ? AND isSubmitted = 1',
      [businessDate],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance;
    await db.delete('tank_dips', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countForBusinessDate(String businessDate) async {
    final db = await AppDatabase.instance;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM tank_dips WHERE businessDate = ? AND isArchived = 0',
      [businessDate],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<void> deleteEmptyDrafts(String businessDate) async {
    final db = await AppDatabase.instance;
    await db.delete(
      'tank_dips',
      where: "businessDate = ? AND isSubmitted = 0 "
          "AND openingLevel = 0 AND closingLevel = 0 "
          "AND (notes IS NULL OR notes = '')",
      whereArgs: [businessDate],
    );
  }
}