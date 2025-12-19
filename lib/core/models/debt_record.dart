// lib/core/models/debt_record.dart

class DebtRecord {
  final String id;
  final String supplier;
  final String fuelType;
  double amount;
  final DateTime createdAt;
  bool settled;

  DebtRecord({
    required this.id,
    required this.supplier,
    required this.fuelType,
    required this.amount,
    required this.createdAt,
    this.settled = false,
  });

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
        'settled': settled,
      };
}
