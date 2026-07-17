import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_record.dart';
import '../../features/auth/repositories/user_repo.dart';

class AuthService with ChangeNotifier {
  final UserRepo repo;

  AuthService({required this.repo});

  UserRecord? _currentUser;
  UserRecord? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isOwner => _currentUser?.isOwner ?? false;

  SupabaseClient get _supabase => Supabase.instance.client;

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

  /// Registers the account with Supabase Auth first (requires internet —
  /// this is the deliberate "online once, at creation" checkpoint). Only
  /// once that succeeds do we create the matching local record, so local
  /// and cloud never drift out of sync with each other.
  Future<void> _registerWithSupabase(String email, String password) async {
    try {
      await _supabase.auth.signUp(email: email, password: password);
    } on AuthException catch (e) {
      throw Exception('Cloud registration failed: ${e.message}');
    } on SocketException {
      throw Exception('No internet connection. Creating an account needs '
          'internet the first time, to register the email with the cloud.');
    } catch (e) {
      throw Exception('Could not reach the cloud to register this account. '
          'Check your internet connection and try again.');
    }
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

    await _registerWithSupabase(cleanEmail, password);

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
  ///
  /// NOTE: Supabase's client-side signUp() automatically switches the
  /// active cloud session to the newly created account, so after this
  /// call the ambient Supabase session belongs to the new Manager, not
  /// the Owner who created it. Harmless today (RLS only checks "is
  /// authenticated"), but worth knowing if role-specific cloud behavior
  /// gets added later.
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

    // Manager accounts are local-only — no Supabase registration needed.
    // Send Data checks for an active Supabase session on the device as
    // a whole (via SyncService.hasSupabaseSession), not per-user, and
    // the Owner's own account already establishes that session. Manager
    // password recovery is handled locally by the Owner (Manage Staff),
    // so there's no cloud dependency Manager accounts actually need.

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

  /// Local, offline login — checked against the hashed credential stored
  /// on this device. This is the everyday login path and never touches
  /// the network.
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

  /// Cloud re-authentication — only needed when Send Data can't find a
  /// valid Supabase session (e.g. expired/cleared session on a machine
  /// that's been offline a while). Does not touch or replace local login.
  Future<void> signInToCloud({required String email, required String password}) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on AuthException catch (e) {
      throw Exception('Cloud sign-in failed: ${e.message}');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      throw Exception('Could not reach the cloud. Check your internet connection.');
    }
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  /// Registers the CURRENTLY LOGGED-IN local account with Supabase after
  /// the fact — for accounts created before cloud registration was wired
  /// in, or a fresh install missing its session. Owner-only, since Owner
  /// is the identity whose Supabase session backs Send Data for the
  /// whole device.
  Future<void> linkCurrentAccountToCloud({required String password}) async {
    if (!isOwner) throw Exception('Only the Owner account can be linked to the cloud');
    final user = _currentUser;
    if (user == null) throw Exception('Not logged in');

    // Verify the password matches this device's local record before
    // sending it to Supabase — prevents linking with a mistyped password
    // that would otherwise silently create a mismatched cloud account.
    final hash = _hash(password, user.salt);
    if (hash != user.passwordHash) {
      throw Exception('Incorrect password');
    }

    await _registerWithSupabase(user.email, password);
  }

  Future<List<UserRecord>> fetchAllStaff() => repo.fetchAll();

  Future<void> deleteStaff(String id) async {
    if (!isOwner) throw Exception('Only the Owner can remove staff accounts');
    if (id == _currentUser?.id) throw Exception('Cannot delete your own account while logged in');
    await repo.delete(id);
    notifyListeners();
  }
}