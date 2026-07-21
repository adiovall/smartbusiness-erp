import 'package:sqflite/sqflite.dart';
import '../../../core/db/app_database.dart';
import '../../../core/models/debt_payment_record.dart';

class DebtPaymentRepo {
  Future<void> insert(DebtPaymentRecord r) async {
    final db = await AppDatabase.instance;
    await db.insert('debt_payments', r.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<DebtPaymentRecord>> fetchForBusinessDate(String businessDate) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('debt_payments', where: 'paidByBusinessDate = ?', whereArgs: [businessDate]);
    return rows.map((r) => DebtPaymentRecord.fromJson(r)).toList();
  }

  Future<void> deleteForBusinessDate(String businessDate) async {
    final db = await AppDatabase.instance;
    await db.delete('debt_payments', where: 'paidByBusinessDate = ?', whereArgs: [businessDate]);
  }
}