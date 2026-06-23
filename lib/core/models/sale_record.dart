// lib/core/models/sale_record.dart

class SaleRecord {
  final String id;
  final DateTime date;
  final String businessDate;
  final String pumpNo;
  final String fuelType;
  final double opening;   // ← NEW
  final double closing;   // ← NEW
  final double liters;
  final double unitPrice;
  final double totalAmount;
  final bool isArchived;

  SaleRecord({
    required this.id,
    required this.date,
    String? businessDate,
    required this.pumpNo,
    required this.fuelType,
    this.opening = 0.0,    // ← NEW
    this.closing = 0.0,    // ← NEW
    required this.liters,
    required this.unitPrice,
    this.isArchived = false,
  })  : totalAmount = liters * unitPrice,
        businessDate = businessDate ?? _dateKey(date);

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'businessDate': businessDate,
        'pumpNo': pumpNo,
        'fuelType': fuelType,
        'opening': opening,     // ← NEW
        'closing': closing,     // ← NEW
        'liters': liters,
        'unitPrice': unitPrice,
        'totalAmount': totalAmount,
        'isArchived': isArchived ? 1 : 0,
      };

  factory SaleRecord.fromJson(Map<String, dynamic> json) {
    final d = DateTime.parse(json['date'] as String);
    return SaleRecord(
      id: json['id'] as String,
      date: d,
      businessDate: (json['businessDate'] as String?) ?? _dateKey(d),
      pumpNo: json['pumpNo'] as String,
      fuelType: json['fuelType'] as String,
      opening: (json['opening'] as num?)?.toDouble() ?? 0.0,   // ← NEW
      closing: (json['closing'] as num?)?.toDouble() ?? 0.0,   // ← NEW
      liters: (json['liters'] as num).toDouble(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
      isArchived: ((json['isArchived'] as int?) ?? 0) == 1,
    );
  }

  @override
  String toString() {
    return 'SaleRecord{pump: $pumpNo, fuel: $fuelType, liters: $liters, amount: $totalAmount}';
  }
}