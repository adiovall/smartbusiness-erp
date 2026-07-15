class PumpConfigRecord {
  final String pumpNo;
  final String fuelType; // stored as canonical abbreviation: PMS/AGO/DPK/Gas

  PumpConfigRecord({required this.pumpNo, required this.fuelType});

  Map<String, dynamic> toJson() => {'pumpNo': pumpNo, 'fuelType': fuelType};

  factory PumpConfigRecord.fromJson(Map<String, dynamic> json) {
    return PumpConfigRecord(
      pumpNo: json['pumpNo'] as String,
      fuelType: json['fuelType'] as String,
    );
  }
}