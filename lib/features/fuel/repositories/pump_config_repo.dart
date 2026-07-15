import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../core/db/app_database.dart';
import '../../../core/models/pump_config_record.dart';

class PumpConfigRepo {
  Future<List<PumpConfigRecord>> fetchAll() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('pump_config');
    final list = rows.map(PumpConfigRecord.fromJson).toList();
    list.sort((a, b) =>
        (int.tryParse(a.pumpNo) ?? 0).compareTo(int.tryParse(b.pumpNo) ?? 0));
    return list;
  }

  /// Replaces the entire pump configuration atomically — used when the
  /// settings dialog saves, since pump count and assignments change
  /// together as one unit rather than incrementally.
  Future<void> replaceAll(List<PumpConfigRecord> records) async {
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      await txn.delete('pump_config');
      for (final r in records) {
        await txn.insert('pump_config', r.toJson());
      }
    });
  }
}