// lib/core/db/app_database.dart

import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;

    // Required for Windows / Desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dbPath = join(await getDatabasesPath(), 'smartbusiness.db');

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );

    return _db!;
  }

  static Future<void> _onCreate(Database db, int version) async {
    // SALES
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        date TEXT,
        pumpNo TEXT,
        fuelType TEXT,
        liters REAL,
        unitPrice REAL,
        totalAmount REAL
      )
    ''');

    // DELIVERIES
    await db.execute('''
      CREATE TABLE deliveries (
        id TEXT PRIMARY KEY,
        date TEXT,
        supplier TEXT,
        fuelType TEXT,
        liters REAL,
        totalCost REAL,
        amountPaid REAL,
        source TEXT,
        debt REAL,
        credit REAL
      )
    ''');

    // DEBTS
    await db.execute('''
      CREATE TABLE debts (
        id TEXT PRIMARY KEY,
        supplier TEXT,
        fuelType TEXT,
        amount REAL,
        createdAt TEXT,
        settled INTEGER
      )
    ''');

    // SETTLEMENTS
    await db.execute('''
      CREATE TABLE settlements (
        id TEXT PRIMARY KEY,
        supplier TEXT,
        fuelType TEXT,
        paidAmount REAL,
        remainingDebt REAL,
        credit REAL,
        source TEXT,
        date TEXT
      )
    ''');

    // TANKS
    await db.execute('''
      CREATE TABLE tanks (
        fuelType TEXT PRIMARY KEY,
        capacity REAL,
        currentLevel REAL
      )
    ''');

    // EXPENSES
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        amount REAL,
        category TEXT,
        comment TEXT,
        source TEXT,
        refId TEXT,
        isLocked INTEGER,
        date TEXT
      )
    ''');
  }
}
