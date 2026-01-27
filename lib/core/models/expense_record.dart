// lib/core/models/expense_record.dart

class ExpenseRecord {
  final String id;
  final DateTime date;
  final double amount;
  final String category;
  final String comment;
  final String source;
  final String? refId;
  final bool isLocked;
  final bool isSubmitted;
  final bool isArchived;

  ExpenseRecord({
    required this.id,
    required this.date,
    required this.amount,
    required this.category,
    required this.comment,
    required this.source,
    this.refId,
    this.isLocked = false,
    this.isSubmitted = false,
    this.isArchived = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'amount': amount,
        'category': category,
        'comment': comment,
        'source': source,
        'refId': refId,
        'isLocked': isLocked ? 1 : 0,
        'isSubmitted': isSubmitted ? 1 : 0,
        'isArchived': isArchived ? 1 : 0,
      };

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) {
    return ExpenseRecord(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      comment: (json['comment'] as String?) ?? '',
      source: (json['source'] as String?) ?? '',
      refId: json['refId'] as String?,
      isLocked: (json['isLocked'] as int? ?? 0) == 1,
      isSubmitted: (json['isSubmitted'] as int? ?? 0) == 1,
      isArchived: (json['isArchived'] as int? ?? 0) == 1,
    );
  }
}