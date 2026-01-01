// lib/core/services/expense_service.dart

import 'package:flutter/foundation.dart'; // ← ADD THIS IMPORT
import '../models/expense_record.dart';
import '../../features/fuel/repositories/expense_repo.dart';

class ExpenseService with ChangeNotifier { // ← ADD with ChangeNotifier
  final ExpenseRepo repo;
  final List<ExpenseRecord> _expenses = [];

  ExpenseService(this.repo);

  /// Load all expenses from database on app startup
  Future<void> loadFromDb() async {
    final rows = await repo.fetchAll();
    _expenses
      ..clear()
      ..addAll(rows);
    notifyListeners(); // ← Notify UI that data is loaded
  }

  /// General method to create any expense — used by ExpenseTab, sales shortage, etc.
  Future<void> createExpense({
    required double amount,
    required String category,
    String comment = '',
    String source = '',
    String? refId,
    bool isLocked = false,
  }) async {
    final expense = ExpenseRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      amount: amount,
      category: category,
      comment: comment,
      source: source,
      refId: refId,
      isLocked: isLocked,
    );

    _expenses.add(expense);
    await repo.insert(expense);
    notifyListeners(); // ← Critical: notify UI (ExpenseTab & main screen)
  }

  /// Create a locked expense from sales shortage
  Future<void> addLockedExpenseFromSales({
    required double amount,
    required String comment,
    required String salesBatchRefId,
  }) async {
    await createExpense(
      amount: amount,
      category: 'Sales Shortage',
      comment: comment,
      source: 'Sales',
      refId: salesBatchRefId,
      isLocked: true,
    );
  }

  /// Remove all expenses linked to a sales batch (called when "Undo All" in Sales)
  Future<void> removeByRef(String refId) async {
    final removed = _expenses.where((e) => e.refId == refId).toList();

    _expenses.removeWhere((e) => e.refId == refId);

    for (final e in removed) {
      await repo.delete(e.id);
    }

    notifyListeners(); // ← Update UI after removal
  }

  /// Get total expense amount for today — synchronous (data already loaded)
  double get todayTotal {
    final today = DateTime.now();
    return _expenses
        .where((e) =>
            e.date.year == today.year &&
            e.date.month == today.month &&
            e.date.day == today.day)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  /// Alias for main screen consistency
  double get getTodayTotalAmount => todayTotal;

  /// Get all expenses (read-only)
  List<ExpenseRecord> get all => List.unmodifiable(_expenses);

  /// Get only today's expenses (for ExpenseTab display)
  List<ExpenseRecord> get todayExpenses {
    final today = DateTime.now();
    return _expenses.where((e) =>
        e.date.year == today.year &&
        e.date.month == today.month &&
        e.date.day == today.day).toList();
  }

  /// Optional: Get expenses by category
  List<ExpenseRecord> expensesByCategory(String category) {
    return _expenses.where((e) => e.category == category).toList();
  }
}