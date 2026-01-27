//lib/core/services/expense_service.dart

import 'package:flutter/foundation.dart';
import 'service_registry.dart';
import '../models/expense_record.dart';
import '../../features/fuel/repositories/expense_repo.dart';

class ExpenseService with ChangeNotifier {
  final ExpenseRepo repo;
  final List<ExpenseRecord> _expenses = [];

  ExpenseService(this.repo);

  List<ExpenseRecord> get all => List.unmodifiable(_expenses);

  Future<void> loadFromDb() async {
    final rows = await repo.fetchAll();
    _expenses
      ..clear()
      ..addAll(rows);
    notifyListeners();
  }

  Future<void> refreshToday() async {
    final rows = await repo.fetchAllTodayExpenses(); // only non-archived

    final today = DateTime.now();
    _expenses.removeWhere((e) =>
        e.date.year == today.year &&
        e.date.month == today.month &&
        e.date.day == today.day);

    _expenses.addAll(rows);
    notifyListeners();
  }

  Future<void> createDraftExpense({
    required double amount,
    required String category,
    String comment = '',
  }) async {
    final expense = ExpenseRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      amount: amount,
      category: category,
      comment: comment,
      source: 'Manual',
      isLocked: false,
      isSubmitted: false,
      isArchived: false,
    );

    _expenses.add(expense);
    await repo.insert(expense);
    notifyListeners();
  }

  Future<void> createExpense({
    required double amount,
    required String category,
    String comment = '',
    String source = '',
    String? refId,
    bool isLocked = false,
    bool isSubmitted = true,
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
      isSubmitted: isSubmitted,
      isArchived: false,
    );

    _expenses.add(expense);
    await repo.insert(expense);
    notifyListeners();
  }

  Future<void> createLockedExpense({
    required double amount,
    required String category,
    required String comment,
    required String source,
    required String refId,
    required DateTime date,
  }) async {
    final expense = ExpenseRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: date,
      amount: amount,
      category: category,
      comment: comment,
      source: source,
      refId: refId,
      isLocked: true,
      isSubmitted: true,
      isArchived: false,
    );

    _expenses.add(expense);
    await repo.insert(expense);
    notifyListeners();
  }

  Future<void> updateDraftExpense({
    required String id,
    required double amount,
    required String category,
    required String comment,
  }) async {
    final idx = _expenses.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    final old = _expenses[idx];
    if (old.isLocked || old.isSubmitted) {
      throw Exception('Cannot edit submitted/locked expense');
    }

    final updated = ExpenseRecord(
      id: old.id,
      date: old.date,
      amount: amount,
      category: category,
      comment: comment,
      source: old.source,
      refId: old.refId,
      isLocked: old.isLocked,
      isSubmitted: old.isSubmitted,
      isArchived: old.isArchived,
    );

    _expenses[idx] = updated;
    await repo.update(updated);
    notifyListeners();
  }

  Future<void> deleteDraftExpense(String id) async {
    final e = _expenses.firstWhere((x) => x.id == id);
    if (e.isLocked || e.isSubmitted) {
      throw Exception('Cannot delete submitted/locked expense');
    }

    _expenses.removeWhere((x) => x.id == id);
    await repo.delete(id);
    notifyListeners();
  }

  Future<void> clearTodayDrafts() async {
    await repo.deleteDraftsToday();

    final today = DateTime.now();
    _expenses.removeWhere((e) =>
        e.date.year == today.year &&
        e.date.month == today.month &&
        e.date.day == today.day &&
        !e.isLocked &&
        !e.isSubmitted);

    notifyListeners();
  }

  Future<int> submitTodayExpenses() async {
  final drafts = await repo.fetchTodayDrafts(); // ✅ drafts only

    final n = DateTime.now();
    final todayKey = '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';

    // Always tick weekly summary on submit attempt (even if 0)
    await Services.dayEntry.submitSection(
      businessDate: todayKey,
      section: 'Exp',
      submittedAt: DateTime.now(),
    );

    if (drafts.isEmpty) {
      await refreshToday();
      return 0;
    }

    // ✅ mark only drafts as submitted
    await repo.markSubmittedByIds(drafts.map((e) => e.id).toList());

    await refreshToday();
    return drafts.length;
  }


  List<ExpenseRecord> get todayExpenses {
    final t = DateTime.now();
    return _expenses
        .where((e) =>
            e.date.year == t.year &&
            e.date.month == t.month &&
            e.date.day == t.day)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // Drafts only (editable items)
  List<ExpenseRecord> get todayDrafts {
    final t = DateTime.now();
    return _expenses
        .where((e) =>
            e.date.year == t.year &&
            e.date.month == t.month &&
            e.date.day == t.day &&
            !e.isSubmitted &&
            !e.isLocked &&
            !e.isArchived)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }


  // All today's expenses (drafts + submitted, non-archived)
  List<ExpenseRecord> get allTodayExpenses {
  final t = DateTime.now();
    return _expenses
        .where((e) =>
            e.date.year == t.year &&
            e.date.month == t.month &&
            e.date.day == t.day &&
            !e.isArchived) // ✅ add this
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }


  // Filtered total for UI display (drafts only)
  double get todayTotal {
    return todayDrafts.fold(0.0, (sum, e) => sum + e.amount);
  }

  // Full total for calculations (available sales, reports) - use this!
  double get todayExpenseTotal {
    return allTodayExpenses.fold(0.0, (sum, e) => sum + e.amount);
  }

  // Async version if you need DB-direct (for delivery_tab _refreshNetSales)
    Future<double> get todayCommittedExpenseTotal async {
    final allToday = await repo.fetchAllTodayExpenses();
    return allToday.fold<double>(0.0, (sum, e) => sum + e.amount);
  }
}