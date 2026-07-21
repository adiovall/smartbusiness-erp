class CreditConsumptionRecord {
  final String id;
  final String deliveryId;
  final double amount;
  final String consumedByBusinessDate;
  final String? consumedByRefId;
  final DateTime createdAt;

  CreditConsumptionRecord({
    required this.id,
    required this.deliveryId,
    required this.amount,
    required this.consumedByBusinessDate,
    this.consumedByRefId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'deliveryId': deliveryId,
    'amount': amount,
    'consumedByBusinessDate': consumedByBusinessDate,
    'consumedByRefId': consumedByRefId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory CreditConsumptionRecord.fromJson(Map<String, dynamic> json) => CreditConsumptionRecord(
    id: json['id'] as String,
    deliveryId: json['deliveryId'] as String,
    amount: (json['amount'] as num).toDouble(),
    consumedByBusinessDate: json['consumedByBusinessDate'] as String,
    consumedByRefId: json['consumedByRefId'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}