// lib/features/fuel/repositories/day_entry_repo.dart

import 'package:sqflite/sqflite.dart';
import '../../../core/db/app_database.dart';
import '../../../core/models/day_entry.dart';

class DayEntryRepo {
  /* ===================== UPSERT ===================== */

  Future<void> upsert(DayEntry d) async {
    final db = await AppDatabase.instance;

    await db.insert(
      'day_entries',
      d.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /* ===================== FETCH ONE ===================== */

  Future<DayEntry?> fetchByDate(String date) async {
    final db = await AppDatabase.instance;

    final rows = await db.query(
      'day_entries',
      where: 'date = ?',
      whereArgs: [date],
    );

    if (rows.isEmpty) return null;
    return DayEntry.fromJson(rows.first);
  }

  /* ===================== FETCH WEEK ===================== */

  Future<List<DayEntry>> fetchWeek(DateTime weekStart) async {
    final db = await AppDatabase.instance;

    final start =
        weekStart.toIso8601String().split('T').first;
    final end =
        weekStart.add(const Duration(days: 6))
            .toIso8601String()
            .split('T')
            .first;

    final rows = await db.query(
      'day_entries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'date ASC',
    );

    return rows.map(DayEntry.fromJson).toList();
  }
}
