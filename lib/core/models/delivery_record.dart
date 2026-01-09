// lib/core/models/delivery_record.dart

class DeliveryRecord {
  final String id;
  final DateTime date;
  final String supplier;
  final String fuelType;

  final double liters;
  final double totalCost;
  final double amountPaid;

  final double salesPaid;
  final double externalPaid;

  final String source;

  double debt;
  double credit;

  // ✅ lock flag (editable until submit)
  final int isSubmitted; // 0 = draft, 1 = submitted

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
    this.debt = 0.0,
    this.credit = 0.0,
    this.isSubmitted = 0,
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
        'source': source,
        'debt': debt,
        'credit': credit,
        'isSubmitted': isSubmitted,
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
      source: (json['source'] as String?) ?? '',
      debt: (json['debt'] as num?)?.toDouble() ?? 0.0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0.0,
      isSubmitted: (json['isSubmitted'] as num?)?.toInt() ?? 0,
    );
  }
}
