// lib/features/fuel/repositories/delivery_repo.dart

import 'package:sqflite/sqflite.dart';
import '../../../core/db/app_database.dart';
import '../../../core/models/delivery_record.dart';

class DeliveryRepo {
  Future<void> insert(DeliveryRecord d) async {
    final db = await AppDatabase.instance;

    await db.insert(
      'deliveries',
      {
        'id': d.id,
        'date': d.date.toIso8601String(),
        'supplier': d.supplier,
        'fuelType': d.fuelType,
        'liters': d.liters,
        'totalCost': d.totalCost,
        'amountPaid': d.amountPaid,
        'source': d.source,
        'debt': d.debt,
        'credit': d.credit,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

