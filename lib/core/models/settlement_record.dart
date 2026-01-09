// lib/core/models/settlement_record.dart

class SettlementRecord {
  final String id;
  final String supplier;
  final String fuelType;

  final double paidAmount;

  // ✅ split tracking
  final double salesPaid;
  final double externalPaid;

  final double remainingDebt;
  final double credit;
  final String source;
  final DateTime date;

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
  });

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
      };

  factory SettlementRecord.fromJson(Map<String, dynamic> json) {
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
      date: DateTime.parse(json['date'] as String),
    );
  }
}
