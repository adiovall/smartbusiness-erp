import 'package:sqflite/sqflite.dart';
import '../../../core/db/app_database.dart';
import '../../../core/models/credit_consumption_record.dart';

class CreditConsumptionRepo {
  Future<void> insert(CreditConsumptionRecord r) async {
    final db = await AppDatabase.instance;
    await db.insert('credit_consumptions', r.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CreditConsumptionRecord>> fetchForBusinessDate(String businessDate) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('credit_consumptions', where: 'consumedByBusinessDate = ?', whereArgs: [businessDate]);
    return rows.map((r) => CreditConsumptionRecord.fromJson(r)).toList();
  }

  Future<List<CreditConsumptionRecord>> fetchForDeliveryIds(Set<String> ids) async {
    if (ids.isEmpty) return [];
    final db = await AppDatabase.instance;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.query('credit_consumptions', where: 'deliveryId IN ($placeholders)', whereArgs: ids.toList());
    return rows.map((r) => CreditConsumptionRecord.fromJson(r)).toList();
  }

  Future<void> deleteForBusinessDate(String businessDate) async {
    final db = await AppDatabase.instance;
    await db.delete('credit_consumptions', where: 'consumedByBusinessDate = ?', whereArgs: [businessDate]);
  }
}