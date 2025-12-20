// lib/core/services/expense_service.dart

import '../models/expense_record.dart';
import '../../features/fuel/repositories/expense_repo.dart';

class ExpenseService {
  final ExpenseRepo repo;
  final List<ExpenseRecord> _expenses = [];

  ExpenseService(this.repo);

  /// 🔄 Load from DB on app start
  Future<void> loadFromDb() async {
    final rows = await repo.fetchAll();
    _expenses
      ..clear()
      ..addAll(rows);
  }

  /// 🔒 Locked expense coming from sales mismatch
  Future<void> addLockedExpense({
    required double amount,
    required String comment,
    required String refId,
  }) async {
    final expense = ExpenseRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      amount: amount,
      category: 'Sales Adjustment',
      comment: comment,
      source: 'Sales',
      refId: refId,
      isLocked: true,
    );

    _expenses.add(expense);
    await repo.insert(expense);
  }

  /// ❌ Used when SALE is undone
  Future<void> removeByRef(String refId) async {
    _expenses.removeWhere((e) => e.refId == refId);
    await repo.deleteByRef(refId);
  }

  List<ExpenseRecord> get all =>
      List.unmodifiable(_expenses);
}
