// lib/core/models/tank_dip_record.dart

class TankDipRecord {
  final String id;
  final String businessDate;
  final String fuelType;
  final double openingLevel;
  final double closingLevel;
  final String? notes;
  final bool isSubmitted;
  final bool isArchived;
  final DateTime createdAt;

  TankDipRecord({
    required this.id,
    required this.businessDate,
    required this.fuelType,
    required this.openingLevel,
    required this.closingLevel,
    this.notes,
    this.isSubmitted = false,
    this.isArchived = false,
    required this.createdAt,
  });

  double get variance => closingLevel - openingLevel;

  Map<String, dynamic> toJson() => {
    'id': id,
    'businessDate': businessDate,
    'fuelType': fuelType,
    'openingLevel': openingLevel,
    'closingLevel': closingLevel,
    'notes': notes,
    'isSubmitted': isSubmitted ? 1 : 0,
    'isArchived': isArchived ? 1 : 0,
    'createdAt': createdAt.toIso8601String(),
  };

  factory TankDipRecord.fromJson(Map<String, dynamic> json) {
    return TankDipRecord(
      id: json['id'] as String,
      businessDate: json['businessDate'] as String,
      fuelType: json['fuelType'] as String,
      openingLevel: (json['openingLevel'] as num?)?.toDouble() ?? 0.0,
      closingLevel: (json['closingLevel'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      isSubmitted: ((json['isSubmitted'] as int?) ?? 0) == 1,
      isArchived: ((json['isArchived'] as int?) ?? 0) == 1,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  TankDipRecord copyWith({
    double? openingLevel,
    double? closingLevel,
    String? notes,
    bool? isSubmitted,
    bool? isArchived,
  }) {
    return TankDipRecord(
      id: id,
      businessDate: businessDate,
      fuelType: fuelType,
      openingLevel: openingLevel ?? this.openingLevel,
      closingLevel: closingLevel ?? this.closingLevel,
      notes: notes ?? this.notes,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
    );
  }
}