// lib/core/models/debt_record.dart

class DebtRecord {
  final String id;
  final String supplier;
  final String fuelType;
  double amount;

  final DateTime createdAt;
  String businessDate;   // ← NEW, mutable so it can be corrected on send

  bool settled;

  DebtRecord({
    required this.id,
    required this.supplier,
    required this.fuelType,
    required this.amount,
    required this.createdAt,
    String? businessDate,       // ← NEW
    this.settled = false,
  }) : businessDate = businessDate ?? _dateKey(createdAt);

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime get date => createdAt;

  void applyPayment(double payment) {
    amount -= payment;
    if (amount <= 0) {
      amount = 0;
      settled = true;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'supplier': supplier,
        'fuelType': fuelType,
        'amount': amount,
        'createdAt': createdAt.toIso8601String(),
        'businessDate': businessDate,   // ← NEW
        'settled': settled ? 1 : 0,
      };

  factory DebtRecord.fromJson(Map<String, dynamic> json) {
    final c = DateTime.parse(json['createdAt'] as String);
    return DebtRecord(
      id: json['id'] as String,
      supplier: (json['supplier'] as String?) ?? '',
      fuelType: (json['fuelType'] as String?) ?? '',
      amount: (json['amount'] as num).toDouble(),
      createdAt: c,
      businessDate: (json['businessDate'] as String?) ?? _dateKey(c),  // ← NEW
      settled: ((json['settled'] as int?) ?? 0) == 1,
    );
  }
}