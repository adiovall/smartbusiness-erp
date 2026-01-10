// lib/core/services/expense_service.dart

import 'package:flutter/foundation.dart';
import '../models/expense_record.dart';
import '../../features/fuel/repositories/expense_repo.dart';

class ExpenseService with ChangeNotifier {
  final ExpenseRepo repo;
  final List<ExpenseRecord> _expenses = [];

  ExpenseService(this.repo);

  Future<void> loadFromDb() async {
    final rows = await repo.fetchAll();
    _expenses
      ..clear()
      ..addAll(rows);
    notifyListeners();
  }

  /// ✅ General method to create any expense
  /// NEW: you can pass a custom [date] (needed for Delivery Submit / Sales submit etc.)
  Future<void> createExpense({
    required double amount,
    required String category,
    String comment = '',
    String source = '',
    String? refId,
    bool isLocked = false,
    DateTime? date,
  }) async {
    final expense = ExpenseRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: date ?? DateTime.now(),
      amount: amount,
      category: category,
      comment: comment,
      source: source,
      refId: refId,
      isLocked: isLocked,
    );

    _expenses.add(expense);
    await repo.insert(expense);
    notifyListeners();
  }

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

  /// ✅ Used by Delivery Submit: Sales part becomes Expense & LOCKED
  Future<void> createLockedExpense({
    required double amount,
    required String category,
    required String comment,
    required String source,
    required String refId,
    required DateTime date,
  }) async {
    await createExpense(
      amount: amount,
      category: category,
      comment: comment,
      source: source,
      refId: refId,
      isLocked: true,
      date: date,
    );
  }

  Future<void> removeByRef(String refId) async {
    final removed = _expenses.where((e) => e.refId == refId).toList();
    _expenses.removeWhere((e) => e.refId == refId);

    for (final e in removed) {
      await repo.delete(e.id);
    }

    notifyListeners();
  }

  double get todayTotal {
    final today = DateTime.now();
    return _expenses
        .where((e) =>
            e.date.year == today.year &&
            e.date.month == today.month &&
            e.date.day == today.day)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get getTodayTotalAmount => todayTotal;

  List<ExpenseRecord> get all => List.unmodifiable(_expenses);

  List<ExpenseRecord> get todayExpenses {
    final today = DateTime.now();
    return _expenses
        .where((e) =>
            e.date.year == today.year &&
            e.date.month == today.month &&
            e.date.day == today.day)
        .toList();
  }

  List<ExpenseRecord> expensesByCategory(String category) {
    return _expenses.where((e) => e.category == category).toList();
  }
}
