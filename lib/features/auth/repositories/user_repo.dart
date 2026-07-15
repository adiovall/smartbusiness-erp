import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../core/db/app_database.dart';
import '../../../core/models/user_record.dart';

class UserRepo {
  Future<void> insert(UserRecord user) async {
    final db = await AppDatabase.instance;
    await db.insert('users', user.toJson(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<UserRecord?> fetchByEmail(String email) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserRecord.fromJson(rows.first);
  }

  Future<List<UserRecord>> fetchAll() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('users', orderBy: 'createdAt ASC');
    return rows.map(UserRecord.fromJson).toList();
  }

  Future<bool> hasAnyOwner() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('users', where: "role = 'owner'", limit: 1);
    return rows.isNotEmpty;
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }
}