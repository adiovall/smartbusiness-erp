import 'package:sqflite/sqflite.dart';
import '../../../core/db/app_database.dart';
import '../../../core/models/sale_record.dart';

class SaleRepo {
  Future<void> insert(SaleRecord s) async {
    final db = await AppDatabase.instance;

    await db.insert(
      'sales',
      s.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SaleRecord>> fetchToday() async {
    final db = await AppDatabase.instance;

    final rows = await db.query('sales');

    return rows.map((r) => SaleRecord(
      id: r['id'] as String,
      date: DateTime.parse(r['date'] as String),
      pumpNo: r['pumpNo'] as String,
      fuelType: r['fuelType'] as String,
      liters: r['liters'] as double,
      unitPrice: r['unitPrice'] as double,
    )).toList();
  }
}
