// lib/core/models/expense_record.dart

class ExpenseRecord {
  final String id;
  final DateTime date;
  final String businessDate;   // ← NEW: yyyy-MM-dd, defaults to date's day
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
    String? businessDate,                              // ← NEW
    required this.amount,
    required this.category,
    required this.comment,
    required this.source,
    this.refId,
    this.isLocked = false,
    this.isSubmitted = false,
    this.isArchived = false,
  }) : businessDate = businessDate ?? _dateKey(date);    // ← NEW

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'businessDate': businessDate,                    // ← NEW
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
    final d = DateTime.parse(json['date'] as String);
    return ExpenseRecord(
      id: json['id'] as String,
      date: d,
      businessDate: (json['businessDate'] as String?) ?? _dateKey(d),  // ← NEW, falls back for old rows
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