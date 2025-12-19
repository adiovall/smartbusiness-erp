// lib/core/models/settlement_record.dart

class SettlementRecord {
  final String id;
  final String supplier;
  final String fuelType;
  final double paidAmount;
  final double remainingDebt;
  final double credit;
  final String source;
  final DateTime date;

  SettlementRecord({
    required this.id,
    required this.supplier,
    required this.fuelType,
    required this.paidAmount,
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
        'remainingDebt': remainingDebt,
        'credit': credit,
        'source': source,
        'date': date.toIso8601String(),
      };
}
