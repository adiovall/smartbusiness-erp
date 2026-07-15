class UserRecord {
  final String id;
  final String email;
  final String passwordHash;
  final String salt;
  final String role; // 'owner' or 'manager'
  final String? name;
  final DateTime createdAt;

  UserRecord({
    required this.id,
    required this.email,
    required this.passwordHash,
    required this.salt,
    required this.role,
    this.name,
    required this.createdAt,
  });

  bool get isOwner => role == 'owner';
  bool get isManager => role == 'manager';

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'passwordHash': passwordHash,
        'salt': salt,
        'role': role,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserRecord.fromJson(Map<String, dynamic> json) {
    return UserRecord(
      id: json['id'] as String,
      email: json['email'] as String,
      passwordHash: json['passwordHash'] as String,
      salt: json['salt'] as String,
      role: json['role'] as String,
      name: json['name'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}