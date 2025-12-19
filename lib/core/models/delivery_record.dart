// lib/core/models/delivery_record.dart

class DeliveryRecord {
  final String id;
  final DateTime date;
  final String supplier;
  final String fuelType;
  final double liters;
  final double totalCost;
  final double amountPaid;
  final String source;

  /// 🔑 STORED STATE (NOT COMPUTED)
  double debt;
  double credit;

  DeliveryRecord({
    required this.id,
    required this.date,
    required this.supplier,
    required this.fuelType,
    required this.liters,
    required this.totalCost,
    required this.amountPaid,
    required this.source,
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
        'source': source,
        'debt': debt,
        'credit': credit,
      };

  factory DeliveryRecord.fromJson(Map<String, dynamic> json) {
    return DeliveryRecord(
      id: json['id'],
      date: DateTime.parse(json['date']),
      supplier: json['supplier'],
      fuelType: json['fuelType'],
      liters: (json['liters'] as num).toDouble(),
      totalCost: (json['totalCost'] as num).toDouble(),
      amountPaid: (json['amountPaid'] as num).toDouble(),
      source: json['source'],
      debt: (json['debt'] as num?)?.toDouble() ?? 0.0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
