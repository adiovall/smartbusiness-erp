// lib/core/services/csv_export_service.dart

import 'dart:convert';
import 'package:csv/csv.dart';
import '../db/app_database.dart';
import '../../features/fuel/repositories/sale_repo.dart';
import '../../features/fuel/repositories/delivery_repo.dart';
import '../../features/fuel/repositories/expense_repo.dart';
import '../../features/fuel/repositories/tank_dip_repo.dart';

class CsvExportService {
  final SaleRepo saleRepo;
  final DeliveryRepo deliveryRepo;
  final ExpenseRepo expenseRepo;
  final TankDipRepo tankDipRepo;

  CsvExportService({
    required this.saleRepo,
    required this.deliveryRepo,
    required this.expenseRepo,
    required this.tankDipRepo,
  });

  static const _fuelTypes = ['PMS', 'AGO', 'DPK', 'Gas'];
  static const _fuelKeys = {'PMS': 'pms', 'AGO': 'ago', 'DPK': 'dpk', 'Gas': 'gas'};

  // Mirrors CsvImportService._expenseCategoryColumns, reversed
  // (category label -> column name), so exported rows re-import cleanly.
  static const _categoryToColumn = {
    'Maintenance': 'expense_maintenance',
    'Salary': 'expense_salary',
    'Generator Fuel': 'expense_generator_fuel',
    'Delivery Payment': 'expense_delivery_payment',
    'Settlement Payment': 'expense_settlement_payment',
    'Sales Shortage': 'expense_shortage',
    'Other': 'expense_other',
    'Misc': 'expense_misc',
  };

  Future<String> exportAllAsCsv() async {
    final dates = await _fetchDistinctBusinessDates();

    final header = [
      'businessDate',
      'pms_revenue', 'pms_liters',
      'ago_revenue', 'ago_liters',
      'dpk_revenue', 'dpk_liters',
      'gas_revenue', 'gas_liters',
      'total_delivery_cost',
      ..._categoryToColumn.values,
      'total_expense',
      'pms_tank_level', 'ago_tank_level', 'dpk_tank_level', 'gas_tank_level',
    ];

    final rows = <List<dynamic>>[header];

    for (final date in dates) {
      rows.add(await _buildRow(date));
    }

    return const ListToCsvConverter().convert(rows);
  }

  Future<List<String>> _fetchDistinctBusinessDates() async {
    final db = await AppDatabase.instance;
    final result = await db.rawQuery('''
      SELECT businessDate FROM sales
      UNION SELECT businessDate FROM deliveries
      UNION SELECT businessDate FROM expenses
      UNION SELECT businessDate FROM tank_dips
      ORDER BY businessDate ASC
    ''');
    return result.map((r) => r['businessDate'] as String).toList();
  }

  Future<List<dynamic>> _buildRow(String date) async {
    final sales = await saleRepo.fetchAllForBusinessDate(date);
    final deliveries = await deliveryRepo.fetchAllForBusinessDate(date);
    final expenses = await expenseRepo.fetchAllForBusinessDate(date);
    final tankDips = await tankDipRepo.fetchAllForBusinessDate(date);

    final row = <String, double>{};
    for (final fuel in _fuelTypes) {
      final key = _fuelKeys[fuel]!;
      final fuelSales = sales.where((s) => s.fuelType == fuel);
      row['${key}_revenue'] = fuelSales.fold(0.0, (sum, s) => sum + s.totalAmount);
      row['${key}_liters'] = fuelSales.fold(0.0, (sum, s) => sum + s.liters);
    }

    final totalDeliveryCost = deliveries.fold(0.0, (sum, d) => sum + d.totalCost);

    final categoryTotals = <String, double>{for (final c in _categoryToColumn.values) c: 0.0};
    double totalExpense = 0.0;
    for (final e in expenses) {
      totalExpense += e.amount;
      final col = _categoryToColumn[e.category];
      if (col != null) {
        categoryTotals[col] = (categoryTotals[col] ?? 0.0) + e.amount;
      }
    }

    final tankLevels = <String, double?>{for (final f in _fuelTypes) f: null};
    for (final t in tankDips) {
      tankLevels[t.fuelType] = t.closingLevel;
    }

    return [
      date,
      row['pms_revenue'], row['pms_liters'],
      row['ago_revenue'], row['ago_liters'],
      row['dpk_revenue'], row['dpk_liters'],
      row['gas_revenue'], row['gas_liters'],
      totalDeliveryCost,
      ..._categoryToColumn.values.map((c) => categoryTotals[c]),
      totalExpense,
      tankLevels['PMS'] ?? '',
      tankLevels['AGO'] ?? '',
      tankLevels['DPK'] ?? '',
      tankLevels['Gas'] ?? '',
    ];
  }
}