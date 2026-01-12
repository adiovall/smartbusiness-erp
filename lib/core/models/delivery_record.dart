// lib/core/models/delivery_record.dart

class DeliveryRecord {
  final String id;
  final DateTime date;
  final String supplier;
  final String fuelType;

  final double liters;
  final double totalCost;

  /// cash actually paid now (Sales + External)
  final double amountPaid;

  /// split
  final double salesPaid;
  final double externalPaid;

  /// overpaid/credit used to offset this delivery (from settlement credits)
  final double creditUsed;

  /// for OVERPAID rows: the original credit amount at creation time
  /// (so settlement can show "Overpaid" and "Remaining")
  final double creditInitial;

  final String source;

  /// 0 = draft, 1 = submitted
  final int isSubmitted;

  double debt;   // remaining debt after (amountPaid + creditUsed)
  double credit; // remaining credit for OVERPAID rows, or extra credit generated

  DeliveryRecord({
    required this.id,
    required this.date,
    required this.supplier,
    required this.fuelType,
    required this.liters,
    required this.totalCost,
    required this.amountPaid,
    required this.source,
    this.salesPaid = 0.0,
    this.externalPaid = 0.0,
    this.creditUsed = 0.0,
    this.creditInitial = 0.0,
    this.isSubmitted = 0,
    this.debt = 0.0,
    this.credit = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'supplier': supplier,
        'fuelType': fuelType,
        'liters': liters,
        'totalCost': totalCost,
        'amountPaid': amountPaid,
        'salesPaid': salesPaid,
        'externalPaid': externalPaid,
        'creditUsed': creditUsed,
        'creditInitial': creditInitial,
        'source': source,
        'isSubmitted': isSubmitted,
        'debt': debt,
        'credit': credit,
      };

  factory DeliveryRecord.fromJson(Map<String, dynamic> json) {
    return DeliveryRecord(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      supplier: (json['supplier'] as String),
      fuelType: (json['fuelType'] as String),
      liters: (json['liters'] as num).toDouble(),
      totalCost: (json['totalCost'] as num).toDouble(),
      amountPaid: (json['amountPaid'] as num).toDouble(),
      salesPaid: (json['salesPaid'] as num?)?.toDouble() ?? 0.0,
      externalPaid: (json['externalPaid'] as num?)?.toDouble() ?? 0.0,
      creditUsed: (json['creditUsed'] as num?)?.toDouble() ?? 0.0,
      creditInitial: (json['creditInitial'] as num?)?.toDouble() ?? 0.0,
      source: (json['source'] as String?) ?? '',
      isSubmitted: (json['isSubmitted'] as int?) ?? 0,
      debt: (json['debt'] as num?)?.toDouble() ?? 0.0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
