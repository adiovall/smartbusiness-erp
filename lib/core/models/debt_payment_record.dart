class DebtPaymentRecord {
  final String id;
  final String debtId;
  final double amount;
  final String paidByBusinessDate;
  final String? paidByRefId;
  final DateTime createdAt;

  DebtPaymentRecord({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.paidByBusinessDate,
    this.paidByRefId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'debtId': debtId,
    'amount': amount,
    'paidByBusinessDate': paidByBusinessDate,
    'paidByRefId': paidByRefId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DebtPaymentRecord.fromJson(Map<String, dynamic> json) => DebtPaymentRecord(
    id: json['id'] as String,
    debtId: json['debtId'] as String,
    amount: (json['amount'] as num).toDouble(),
    paidByBusinessDate: json['paidByBusinessDate'] as String,
    paidByRefId: json['paidByRefId'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}