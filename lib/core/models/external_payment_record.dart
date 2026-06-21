// lib/core/models/external_payment_record.dart

class ExternalPaymentRecord {
  final String id;
  final DateTime date;
  final String businessDate;   // ← NEW
  final String supplier;
  final String fuelType;

  /// amount paid externally
  final double amount;

  /// "Delivery" or "Settlement"
  final String kind;

  /// the original record source column (Sales/External/Sales+External)
  final String source;

  /// 0 draft, 1 submitted (for deliveries). Settlements will be 1.
  final int isSubmitted;

  ExternalPaymentRecord({
    required this.id,
    required this.date,
    required this.businessDate,   // ← NEW
    required this.supplier,
    required this.fuelType,
    required this.amount,
    required this.kind,
    required this.source,
    required this.isSubmitted,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'businessDate': businessDate,
    'supplier': supplier,
    'fuelType': fuelType,
    'amount': amount,
    'kind': kind,
    'source': source,
    'isSubmitted': isSubmitted,
  };
}