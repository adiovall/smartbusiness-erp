// lib/core/services/csv_import_service.dart

import 'dart:convert';
import 'package:csv/csv.dart';
import '../models/outbox_record.dart';
import '../../features/fuel/repositories/outbox_repo.dart';
import 'tank_service.dart';

/// Result of importing one CSV file. Lets the UI show a clear summary
/// of what happened — successes, skips, and errors — rather than a
/// vague "done" message.
class ImportResult {
  final int rowsProcessed;
  final int rowsImported;
  final int rowsSkipped;
  final List<String> warnings;

  ImportResult({
    required this.rowsProcessed,
    required this.rowsImported,
    required this.rowsSkipped,
    required this.warnings,
  });
}

class CsvImportService {
  final OutboxRepo outboxRepo;
  final TankService tankService;

  CsvImportService({required this.outboxRepo, required this.tankService});

  static const _fuelTypes = ['pms', 'ago', 'dpk', 'gas'];
  static const _fuelTypeLabels = {
    'pms': 'PMS',
    'ago': 'AGO',
    'dpk': 'DPK',
    'gas': 'Gas',
  };

  static const _expenseCategoryColumns = {
    'expense_maintenance': 'Maintenance',
    'expense_salary': 'Salary',
    'expense_generator_fuel': 'Generator Fuel',
    'expense_delivery_payment': 'Delivery Payment',
    'expense_settlement_payment': 'Settlement Payment',
    'expense_shortage': 'Sales Shortage',
    'expense_other': 'Other',
    'expense_misc': 'Misc',
  };

  /// Imports a CSV file's contents (already read as a String) into the
  /// outbox table as synthetic historical payloads. Skips any business
  /// date that already has an outbox record (won't overwrite real or
  /// previously-imported data). Returns a summary of what happened.
  Future<ImportResult> importCsv(String csvContent) async {
    final rows = const CsvToListConverter(eol: '\n').convert(csvContent, shouldParseNumbers: false);

    if (rows.isEmpty) {
      return ImportResult(rowsProcessed: 0, rowsImported: 0, rowsSkipped: 0, warnings: ['File is empty']);
    }

    final header = rows.first.map((h) => h.toString().trim().toLowerCase()).toList();
    final dateIdx = header.indexOf('businessdate');

    if (dateIdx == -1) {
      return ImportResult(
        rowsProcessed: 0,
        rowsImported: 0,
        rowsSkipped: 0,
        warnings: ["Missing required column 'businessDate'"],
      );
    }

    final dataRows = rows.skip(1).toList();
    int imported = 0;
    int skipped = 0;
    final warnings = <String>[];

    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      if (row.length < header.length) {
        warnings.add('Row ${i + 2}: column count mismatch, skipped');
        skipped++;
        continue;
      }

      final rowMap = <String, String>{};
      for (int c = 0; c < header.length; c++) {
        rowMap[header[c]] = row[c].toString().trim();
      }

      final businessDate = rowMap['businessdate'] ?? '';
      if (businessDate.isEmpty || !_isValidDate(businessDate)) {
        warnings.add('Row ${i + 2}: invalid or missing businessDate, skipped');
        skipped++;
        continue;
      }

      // Don't overwrite existing data — real or previously imported.
      final existing = await outboxRepo.fetchByBusinessDate(businessDate);
      if (existing != null) {
        warnings.add('$businessDate already has data, skipped (no overwrite)');
        skipped++;
        continue;
      }

      final payload = _buildPayload(businessDate, rowMap, warnings);

      final record = OutboxRecord(
        id: '${DateTime.now().millisecondsSinceEpoch}_import_$i',
        businessDate: businessDate,
        payloadJson: jsonEncode(payload),
        createdAt: DateTime.now(),
        synced: false,
      );

      await outboxRepo.insert(record);
      imported++;
    }

    return ImportResult(
      rowsProcessed: dataRows.length,
      rowsImported: imported,
      rowsSkipped: skipped,
      warnings: warnings,
    );
  }

  bool _isValidDate(String s) {
    final r = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    return r.hasMatch(s);
  }

  double _num(String? v) {
    if (v == null || v.isEmpty) return 0.0;
    return double.tryParse(v) ?? 0.0;
  }

  Map<String, dynamic> _buildPayload(
    String businessDate,
    Map<String, String> row,
    List<String> warnings,
  ) {
    // Synthetic sales: one entry per fuel type that has revenue/liters.
    final sales = <Map<String, dynamic>>[];
    for (final fuel in _fuelTypes) {
      final revenue = _num(row['${fuel}_revenue']);
      final liters = _num(row['${fuel}_liters']);
      if (revenue <= 0 && liters <= 0) continue;

      sales.add({
        'id': 'import_${businessDate}_sale_$fuel',
        'date': '${businessDate}T00:00:00.000',
        'businessDate': businessDate,
        'pumpNo': 'Imported',
        'fuelType': _fuelTypeLabels[fuel],
        'opening': 0.0,
        'closing': 0.0,
        'liters': liters,
        'unitPrice': liters > 0 ? revenue / liters : 0.0,
        'totalAmount': revenue,
        'isArchived': 0,
      });
    }

    // Synthetic deliveries: one lump entry if total_delivery_cost present.
    final deliveries = <Map<String, dynamic>>[];
    final deliveryCost = _num(row['total_delivery_cost']);
    if (deliveryCost > 0) {
      deliveries.add({
        'id': 'import_${businessDate}_delivery',
        'date': '${businessDate}T00:00:00.000',
        'businessDate': businessDate,
        'supplier': 'Imported',
        'fuelType': 'Mixed',
        'liters': 0.0,
        'totalCost': deliveryCost,
        'amountPaid': deliveryCost,
        'salesPaid': 0.0,
        'externalPaid': deliveryCost,
        'creditUsed': 0.0,
        'creditInitial': 0.0,
        'source': 'Imported',
        'isArchived': 0,
        'isSubmitted': 1,
        'debt': 0.0,
        'credit': 0.0,
      });
    }

    // Synthetic expenses: category columns if present, else one lump total.
    final expenses = <Map<String, dynamic>>[];
    bool hasCategoryColumns = false;
    for (final col in _expenseCategoryColumns.keys) {
      final amount = _num(row[col]);
      if (amount > 0) {
        hasCategoryColumns = true;
        expenses.add({
          'id': 'import_${businessDate}_exp_$col',
          'date': '${businessDate}T00:00:00.000',
          'businessDate': businessDate,
          'amount': amount,
          'category': _expenseCategoryColumns[col],
          'comment': 'Imported',
          'source': 'Imported',
          'refId': null,
          'isLocked': 1,
          'isSubmitted': 1,
          'isArchived': 0,
        });
      }
    }
    if (!hasCategoryColumns) {
      final lumpExpense = _num(row['total_expense']);
      if (lumpExpense > 0) {
        expenses.add({
          'id': 'import_${businessDate}_exp_total',
          'date': '${businessDate}T00:00:00.000',
          'businessDate': businessDate,
          'amount': lumpExpense,
          'category': 'Imported',
          'comment': 'Imported from historical records',
          'source': 'Imported',
          'refId': null,
          'isLocked': 1,
          'isSubmitted': 1,
          'isArchived': 0,
        });
      }
    }

    // Tank snapshot: only fuel types with a level column present.
    // Capacity comes from the REAL current tank configuration (assumed
    // stable over time), not guessed from the imported level, so the
    // percentage is meaningful rather than always showing 100%.
    final tankSnapshot = <Map<String, dynamic>>[];
    for (final fuel in _fuelTypes) {
      final levelStr = row['${fuel}_tank_level'];
      if (levelStr == null || levelStr.isEmpty) continue;
      final level = _num(levelStr);

      final fuelLabel = _fuelTypeLabels[fuel]!;
      final realTank = tankService.getTank(fuelLabel);
      final capacity = realTank?.capacity ?? level;

      tankSnapshot.add({
        'fuelType': fuelLabel,
        'capacity': capacity,
        'currentLevel': level,
        'percentage': capacity > 0 ? (level / capacity) * 100 : 0.0,
      });
    }

    if (tankSnapshot.isEmpty) {
      warnings.add('$businessDate: no tank level columns found — Reconciliation will skip this day');
    }

    return {
      'businessDate': businessDate,
      'generatedAt': DateTime.now().toIso8601String(),
      'sales': sales,
      'deliveries': deliveries,
      'debts': [],
      'settlements': [],
      'expenses': expenses,
      'externalPayments': [],
      'tankSnapshot': tankSnapshot,
      'imported': true,
    };
  }
}