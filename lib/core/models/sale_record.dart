// lib/core/models/sale_record.dart

class SaleRecord {
  final String id;
  final DateTime date;
  final String businessDate;
  final String pumpNo;
  final String fuelType;
  final double opening;
  final double closing;
  final double liters;
  final double unitPrice;
  final double totalAmount;
  final bool isArchived;
  final bool isSubmitted;   // ← NEW

  SaleRecord({
    required this.id,
    required this.date,
    String? businessDate,
    required this.pumpNo,
    required this.fuelType,
    this.opening = 0.0,
    this.closing = 0.0,
    required this.liters,
    required this.unitPrice,
    this.isArchived = false,
    this.isSubmitted = false,   // ← NEW
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
        'opening': opening,
        'closing': closing,
        'liters': liters,
        'unitPrice': unitPrice,
        'totalAmount': totalAmount,
        'isArchived': isArchived ? 1 : 0,
        'isSubmitted': isSubmitted ? 1 : 0,   // ← NEW
      };

  factory SaleRecord.fromJson(Map<String, dynamic> json) {
    final d = DateTime.parse(json['date'] as String);
    return SaleRecord(
      id: json['id'] as String,
      date: d,
      businessDate: (json['businessDate'] as String?) ?? _dateKey(d),
      pumpNo: json['pumpNo'] as String,
      fuelType: json['fuelType'] as String,
      opening: (json['opening'] as num?)?.toDouble() ?? 0.0,
      closing: (json['closing'] as num?)?.toDouble() ?? 0.0,
      liters: (json['liters'] as num).toDouble(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
      isArchived: ((json['isArchived'] as int?) ?? 0) == 1,
      isSubmitted: ((json['isSubmitted'] as int?) ?? 0) == 1,   // ← NEW
    );
  }

  SaleRecord copyWith({
    String? pumpNo,
    String? fuelType,
    double? opening,
    double? closing,
    double? liters,
    double? unitPrice,
    bool? isArchived,
    bool? isSubmitted,
  }) {
    return SaleRecord(
      id: id,
      date: date,
      businessDate: businessDate,
      pumpNo: pumpNo ?? this.pumpNo,
      fuelType: fuelType ?? this.fuelType,
      opening: opening ?? this.opening,
      closing: closing ?? this.closing,
      liters: liters ?? this.liters,
      unitPrice: unitPrice ?? this.unitPrice,
      isArchived: isArchived ?? this.isArchived,
      isSubmitted: isSubmitted ?? this.isSubmitted,
    );
  }

  @override
  String toString() {
    return 'SaleRecord{pump: $pumpNo, fuel: $fuelType, liters: $liters, amount: $totalAmount}';
  }
}