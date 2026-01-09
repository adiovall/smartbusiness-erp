// lib/features/fuel/repositories/supplier_repo.dart

import '../../../core/db/app_database.dart';

class SupplierRepo {
  Future<void> upsertActive(String name) async {
    final db = await AppDatabase.instance;
    final n = name.trim();
    if (n.isEmpty) return;

    await db.rawInsert(
      'INSERT OR IGNORE INTO suppliers (id, name, isActive, createdAt) VALUES (?, ?, 1, ?)',
      [DateTime.now().millisecondsSinceEpoch.toString(), n, DateTime.now().toIso8601String()],
    );

    await db.update(
      'suppliers',
      {'isActive': 1},
      where: 'name = ?',
      whereArgs: [n],
    );
  }

  Future<List<Map<String, dynamic>>> fetchAll({bool includeInactive = true}) async {
    final db = await AppDatabase.instance;
    return db.query(
      'suppliers',
      orderBy: 'name ASC',
      where: includeInactive ? null : 'isActive = 1',
    );
  }

  Future<List<String>> fetchActiveNames() async {
    final rows = await fetchAll(includeInactive: false);
    return rows.map((r) => (r['name'] as String)).toList();
  }

  Future<void> renameSupplier(String oldName, String newName) async {
    final db = await AppDatabase.instance;
    final oldN = oldName.trim();
    final newN = newName.trim();
    if (oldN.isEmpty || newN.isEmpty || oldN == newN) return;

    // update supplier registry
    await db.update('suppliers', {'name': newN}, where: 'name = ?', whereArgs: [oldN]);

    // keep history consistent
    await db.update('deliveries', {'supplier': newN}, where: 'supplier = ?', whereArgs: [oldN]);
    await db.update('debts', {'supplier': newN}, where: 'supplier = ?', whereArgs: [oldN]);
    await db.update('settlements', {'supplier': newN}, where: 'supplier = ?', whereArgs: [oldN]);
  }

  Future<void> archiveSupplier(String name) async {
    final db = await AppDatabase.instance;
    await db.update('suppliers', {'isActive': 0}, where: 'name = ?', whereArgs: [name.trim()]);
  }

  Future<void> restoreSupplier(String name) async {
    final db = await AppDatabase.instance;
    await db.update('suppliers', {'isActive': 1}, where: 'name = ?', whereArgs: [name.trim()]);
  }
}
