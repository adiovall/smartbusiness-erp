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

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'pumpNo': pumpNo,
        'fuelType': fuelType,
        'liters': liters,
        'unitPrice': unitPrice,
        'totalAmount': totalAmount,
      };
}


