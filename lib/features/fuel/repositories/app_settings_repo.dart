import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../core/db/app_database.dart';

class AppSettingsRepo {
  Future<String?> get(String key) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('app_settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> set(String key, String value) async {
    final db = await AppDatabase.instance;
    await db.insert('app_settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}