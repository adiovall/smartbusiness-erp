import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final directory = await getApplicationDocumentsDirectory();
    final dbPath = join(directory.path, 'smartbusiness.db');

    _db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 3, // ✅ bump
        onCreate: _onCreate,
        onUpgrade: _onUpgrade, // ✅ migration
      ),
    );

    return _db!;
  }

  static Future<void> _onCreate(Database db, int version) async {
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

    // ✅ deliveries includes salesPaid + externalPaid
    await db.execute('''
      CREATE TABLE deliveries (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        supplier TEXT NOT NULL,
        fuelType TEXT NOT NULL,
        liters REAL NOT NULL,
        totalCost REAL NOT NULL,
        amountPaid REAL NOT NULL DEFAULT 0,
        salesPaid REAL NOT NULL DEFAULT 0,
        externalPaid REAL NOT NULL DEFAULT 0,
        source TEXT,
        debt REAL NOT NULL DEFAULT 0,
        credit REAL NOT NULL DEFAULT 0,
        isSubmitted INTEGER NOT NULL DEFAULT 0

      )
    ''');

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

    await db.execute('''
      CREATE TABLE settlements (
        id TEXT PRIMARY KEY,
        supplier TEXT NOT NULL,
        fuelType TEXT NOT NULL,
        paidAmount REAL NOT NULL,
        salesPaid REAL NOT NULL DEFAULT 0,
        externalPaid REAL NOT NULL DEFAULT 0,
        remainingDebt REAL NOT NULL DEFAULT 0,
        credit REAL NOT NULL DEFAULT 0,
        source TEXT,
        date TEXT NOT NULL
      )
    ''');


    await db.execute('''
      CREATE TABLE tanks (
        fuelType TEXT PRIMARY KEY,
        capacity REAL NOT NULL,
        currentLevel REAL NOT NULL
      )
    ''');

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

      await db.execute('''
        CREATE TABLE day_entries (
          date TEXT PRIMARY KEY,
          sale INTEGER NOT NULL DEFAULT 0,
          delivery INTEGER NOT NULL DEFAULT 0,
          expense INTEGER NOT NULL DEFAULT 0,
          settlement INTEGER NOT NULL DEFAULT 0,
          submittedAt TEXT
        )
      ''');
    }

    static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // ✅ Deliveries lock column
      await db.execute("ALTER TABLE deliveries ADD COLUMN isSubmitted INTEGER NOT NULL DEFAULT 0");

      // ✅ If settlements split columns were not present in old versions
      await db.execute("ALTER TABLE settlements ADD COLUMN salesPaid REAL NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE settlements ADD COLUMN externalPaid REAL NOT NULL DEFAULT 0");
    }
  }

}
