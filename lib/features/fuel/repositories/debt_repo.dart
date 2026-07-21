// lib/features/fuel/repositories/debt_repo.dart

import 'package:sqflite/sqflite.dart';
import '../../../core/db/app_database.dart';
import '../../../core/models/debt_record.dart';

class DebtRepo {
  Future<void> insert(DebtRecord d) async {
    final db = await AppDatabase.instance;

    await db.insert(
      'debts',
      {
        'id': d.id,
        'supplier': d.supplier,
        'fuelType': d.fuelType,
        'amount': d.amount,
        'createdAt': d.createdAt.toIso8601String(),
        'businessDate': d.businessDate,
        'settled': d.settled ? 1 : 0,
        'originalAmount': d.originalAmount,
        
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(DebtRecord d) async {
    final db = await AppDatabase.instance;

    await db.update(
      'debts',
      {
        'amount': d.amount,
        'businessDate': d.businessDate,
        'settled': d.settled ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [d.id],
    );
  }

    /// NEW: needed for the Send-Data business-date correction flow.
    /// Updates only the businessDate for ALL debts that currently belong
    /// to [oldBusinessDate], moving them to [newBusinessDate].
    Future<void> updateBusinessDate(String oldBusinessDate, String newBusinessDate) async {
      final db = await AppDatabase.instance;
      await db.update(
        'debts',
        {'businessDate': newBusinessDate},
        where: 'businessDate = ?',
        whereArgs: [oldBusinessDate],
      );
    }

    Future<void> deleteForBusinessDate(String businessDate) async {
      final db = await AppDatabase.instance;
      await db.delete('debts', where: 'businessDate = ?', whereArgs: [businessDate]);
    }

  /// ✅ REQUIRED BY DebtService
  Future<List<DebtRecord>> fetchAll() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('debts');

    return rows.map((r) {
      return DebtRecord(
        id: r['id'] as String,
        supplier: r['supplier'] as String,
        fuelType: r['fuelType'] as String,
        amount: (r['amount'] as num).toDouble(),
        createdAt: DateTime.parse(r['createdAt'] as String),
        businessDate: r['businessDate'] as String?,   // ← ADD THIS
        settled: (r['settled'] as int) == 1,
        originalAmount: (r['originalAmount'] as num?)?.toDouble() ?? (r['amount'] as num).toDouble(),
      );
    }).toList();
  }
}
