// lib/core/models/outbox_record.dart

class OutboxRecord {
  final String id;
  final String businessDate;
  final String payloadJson;
  final DateTime createdAt;
  final bool synced;

  OutboxRecord({
    required this.id,
    required this.businessDate,
    required this.payloadJson,
    required this.createdAt,
    this.synced = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessDate': businessDate,
        'payloadJson': payloadJson,
        'createdAt': createdAt.toIso8601String(),
        'synced': synced ? 1 : 0,
      };

  factory OutboxRecord.fromJson(Map<String, dynamic> json) {
    return OutboxRecord(
      id: json['id'] as String,
      businessDate: json['businessDate'] as String,
      payloadJson: json['payloadJson'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      synced: ((json['synced'] as int?) ?? 0) == 1,
    );
  }
}