// lib/core/models/debt_record.dart

class DebtRecord {
  final String id;
  final String supplier;
  final String fuelType;
  double amount;

  /// stored in DB as 'createdAt' TEXT
  final DateTime createdAt;

  /// stored in DB as INTEGER 0/1
  bool settled;

  DebtRecord({
    required this.id,
    required this.supplier,
    required this.fuelType,
    required this.amount,
    required this.createdAt,
    this.settled = false,
  });

  /// ✅ Backward-compatible alias (your UI expects d.date)
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
        'settled': settled ? 1 : 0, // ✅ int for DB
      };

  factory DebtRecord.fromJson(Map<String, dynamic> json) {
    return DebtRecord(
      id: json['id'] as String,
      supplier: (json['supplier'] as String?) ?? '',
      fuelType: (json['fuelType'] as String?) ?? '',
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      settled: ((json['settled'] as int?) ?? 0) == 1,
    );
  }
}
