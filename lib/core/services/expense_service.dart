// lib/features/fuel/services/expense_service.dart

import '../../core/models/expense_record.dart';

class ExpenseService {
  final List<ExpenseRecord> _expenses = [];

  /// 🔒 Locked expense coming from sales mismatch
  void addLockedExpense({
    required double amount,
    required String comment,
    required String refId,
  }) {
    _expenses.add(
      ExpenseRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        amount: amount,
        category: 'Sales Adjustment',
        comment: comment,
        source: 'Sales',
        refId: refId,
        isLocked: true,
      ),
    );
  }

  /// ❌ Used when SALE is undone
  void removeByRef(String refId) {
    _expenses.removeWhere((e) => e.refId == refId);
  }

  List<ExpenseRecord> get all => List.unmodifiable(_expenses);
}
