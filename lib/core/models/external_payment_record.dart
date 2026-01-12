// lib/core/models/external_payment_record.dart

class ExternalPaymentRecord {
  final String id;
  final DateTime date;
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
    required this.supplier,
    required this.fuelType,
    required this.amount,
    required this.kind,
    required this.source,
    required this.isSubmitted,
  });
}
