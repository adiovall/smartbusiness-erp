// lib/core/models/settlement_record.dart

class SettlementRecord {
  final String id;
  final String supplier;
  final String fuelType;

  final double paidAmount;

  final double salesPaid;
  final double externalPaid;

  final double remainingDebt;
  final double credit;
  final String source;
  final DateTime date;
  final String businessDate;   // ← NEW

  SettlementRecord({
    required this.id,
    required this.supplier,
    required this.fuelType,
    required this.paidAmount,
    required this.salesPaid,
    required this.externalPaid,
    required this.remainingDebt,
    required this.credit,
    required this.source,
    required this.date,
    String? businessDate,       // ← NEW
  }) : businessDate = businessDate ?? _dateKey(date);

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'supplier': supplier,
        'fuelType': fuelType,
        'paidAmount': paidAmount,
        'salesPaid': salesPaid,
        'externalPaid': externalPaid,
        'remainingDebt': remainingDebt,
        'credit': credit,
        'source': source,
        'date': date.toIso8601String(),
        'businessDate': businessDate,   // ← NEW
      };

  factory SettlementRecord.fromJson(Map<String, dynamic> json) {
    final d = DateTime.parse(json['date'] as String);
    return SettlementRecord(
      id: json['id'] as String,
      supplier: json['supplier'] as String,
      fuelType: json['fuelType'] as String,
      paidAmount: (json['paidAmount'] as num).toDouble(),
      salesPaid: (json['salesPaid'] as num?)?.toDouble() ?? 0.0,
      externalPaid: (json['externalPaid'] as num?)?.toDouble() ?? 0.0,
      remainingDebt: (json['remainingDebt'] as num?)?.toDouble() ?? 0.0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0.0,
      source: (json['source'] as String?) ?? '',
      date: d,
      businessDate: (json['businessDate'] as String?) ?? _dateKey(d),  // ← NEW
    );
  }
}