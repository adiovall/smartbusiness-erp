// lib/core/models/sale_record.dart

class SaleRecord {
  final String id;
  final DateTime date;
  final String pumpNo;
  final String fuelType;
  final double liters;
  final double unitPrice;
  final double totalAmount;

  SaleRecord({
    required this.id,
    required this.date,
    required this.pumpNo,
    required this.fuelType,
    required this.liters,
    required this.unitPrice,
  }) : totalAmount = liters * unitPrice;

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'pumpNo': pumpNo,
        'fuelType': fuelType,
        'liters': liters,
        'unitPrice': unitPrice,
        'totalAmount': totalAmount,
      };

  /// Create from database row
  factory SaleRecord.fromJson(Map<String, dynamic> json) {
    return SaleRecord(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      pumpNo: json['pumpNo'] as String,
      fuelType: json['fuelType'] as String,
      liters: (json['liters'] as num).toDouble(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
    );
  }

  /// Optional: for debugging / logging
  @override
  String toString() {
    return 'SaleRecord{pump: $pumpNo, fuel: $fuelType, liters: $liters, amount: $totalAmount}';
  }
}