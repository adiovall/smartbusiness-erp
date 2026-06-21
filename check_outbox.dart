// check_outbox.dart
//
// One-off script to inspect outbox table contents.
// Run with: dart run check_outbox.dart
// Delete after use.

import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const dbPath = r'C:\Users\HI\Documents\smartbusiness.db';

Future<void> main() async {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;

  final db = await databaseFactory.openDatabase(dbPath);

  final rows = await db.query('outbox', orderBy: 'createdAt DESC');

  print('--- OUTBOX: ${rows.length} record(s) ---\n');

  for (final row in rows) {
    print('id: ${row['id']}');
    print('businessDate: ${row['businessDate']}');
    print('createdAt: ${row['createdAt']}');
    print('synced: ${row['synced']}');
    print('--- payload (pretty) ---');

    final payload = jsonDecode(row['payloadJson'] as String);
    print(const JsonEncoder.withIndent('  ').convert(payload));
    print('\n=======================================\n');
  }

  await db.close();
}