// lib/core/db/app_database.dart

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;

    // Initialize FFI for desktop platforms (Windows, Linux, macOS)
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Get proper documents directory (works on mobile + desktop)
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = join(directory.path, 'smartbusiness.db');

    _db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _onCreate,
      ),
    );

    return _db!;
  }

  static Future<void> _onCreate(Database db, int version) async {
    // SALES TABLE
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        pumpNo TEXT NOT NULL,
        fuelType TEXT NOT NULL,
        liters REAL NOT NULL,
        unitPrice REAL NOT NULL,
        totalAmount REAL NOT NULL
      )
    ''');

    // DELIVERIES TABLE
    await db.execute('''
      CREATE TABLE deliveries (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        supplier TEXT NOT NULL,
        fuelType TEXT NOT NULL,
        liters REAL NOT NULL,
        totalCost REAL NOT NULL,
        amountPaid REAL NOT NULL DEFAULT 0,
        source TEXT,
        debt REAL NOT NULL DEFAULT 0,
        credit REAL NOT NULL DEFAULT 0
      )
    ''');

    // DEBTS TABLE
    await db.execute('''
      CREATE TABLE debts (
        id TEXT PRIMARY KEY,
        supplier TEXT NOT NULL,
        fuelType TEXT NOT NULL,
        amount REAL NOT NULL,
        createdAt TEXT NOT NULL,
        settled INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // SETTLEMENTS TABLE
    await db.execute('''
      CREATE TABLE settlements (
        id TEXT PRIMARY KEY,
        supplier TEXT NOT NULL,
        fuelType TEXT NOT NULL,
        paidAmount REAL NOT NULL,
        remainingDebt REAL NOT NULL DEFAULT 0,
        credit REAL NOT NULL DEFAULT 0,
        source TEXT,
        date TEXT NOT NULL
      )
    ''');

    // TANKS TABLE
    await db.execute('''
      CREATE TABLE tanks (
        fuelType TEXT PRIMARY KEY,
        capacity REAL NOT NULL,
        currentLevel REAL NOT NULL
      )
    ''');

    // EXPENSES TABLE
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        comment TEXT,
        source TEXT,
        refId TEXT,
        isLocked INTEGER NOT NULL DEFAULT 0,
        date TEXT NOT NULL
      )
    ''');

    // DAY ENTRIES STATUS TABLE (for weekly summary)
    await db.execute('''
      CREATE TABLE day_entries (
        date TEXT PRIMARY KEY,
        sale INTEGER NOT NULL DEFAULT 0,          -- 0=none, 1=draft, 2=submitted
        delivery INTEGER NOT NULL DEFAULT 0,
        expense INTEGER NOT NULL DEFAULT 0,
        settlement INTEGER NOT NULL DEFAULT 0,
        submittedAt TEXT
      )
    ''');
  }
}