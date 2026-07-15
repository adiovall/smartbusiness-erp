import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../models/user_record.dart';
import '../../features/auth/repositories/user_repo.dart';

class AuthService with ChangeNotifier {
  final UserRepo repo;

  AuthService({required this.repo});

  UserRecord? _currentUser;
  UserRecord? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isOwner => _currentUser?.isOwner ?? false;

  Future<bool> hasAnyOwner() => repo.hasAnyOwner();

  String _generateSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hash(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  Future<UserRecord> createOwnerAccount({
    required String email,
    required String password,
    String? name,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw Exception('Enter a valid email');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }

    final existing = await repo.fetchByEmail(cleanEmail);
    if (existing != null) throw Exception('An account with this email already exists');

    final salt = _generateSalt();
    final user = UserRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      email: cleanEmail,
      passwordHash: _hash(password, salt),
      salt: salt,
      role: 'owner',
      name: name,
      createdAt: DateTime.now(),
    );

    await repo.insert(user);
    _currentUser = user;
    notifyListeners();
    return user;
  }

  /// Only callable by a logged-in Owner. UI should only expose this via
  /// an Owner-gated "Manage Staff" screen; re-checked here as a safety net.
  Future<UserRecord> createManagerAccount({
    required String email,
    required String password,
    String? name,
  }) async {
    if (!isOwner) throw Exception('Only the Owner can create staff accounts');

    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw Exception('Enter a valid email');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }

    final existing = await repo.fetchByEmail(cleanEmail);
    if (existing != null) throw Exception('An account with this email already exists');

    final salt = _generateSalt();
    final user = UserRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      email: cleanEmail,
      passwordHash: _hash(password, salt),
      salt: salt,
      role: 'manager',
      name: name,
      createdAt: DateTime.now(),
    );

    await repo.insert(user);
    notifyListeners();
    return user;
  }

  Future<UserRecord?> login({required String email, required String password}) async {
    final cleanEmail = email.trim().toLowerCase();
    final user = await repo.fetchByEmail(cleanEmail);
    if (user == null) return null;

    final hash = _hash(password, user.salt);
    if (hash != user.passwordHash) return null;

    _currentUser = user;
    notifyListeners();
    return user;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  Future<List<UserRecord>> fetchAllStaff() => repo.fetchAll();

  Future<void> deleteStaff(String id) async {
    if (!isOwner) throw Exception('Only the Owner can remove staff accounts');
    if (id == _currentUser?.id) throw Exception('Cannot delete your own account while logged in');
    await repo.delete(id);
    notifyListeners();
  }
}