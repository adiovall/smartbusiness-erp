// lib/core/models/expense_record.dart

class ExpenseRecord {
  final String id;
  final DateTime date;
  final double amount;
  final String category;
  final String comment;
  final String source; // e.g. Sales, Delivery
  final String? refId; // links to SaleRecord
  final bool isLocked;

  ExpenseRecord({
    required this.id,
    required this.date,
    required this.amount,
    required this.category,
    required this.comment,
    required this.source,
    this.refId,
    this.isLocked = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'amount': amount,
        'category': category,
        'comment': comment,
        'source': source,
        'refId': refId,
        'isLocked': isLocked,
      };
}
