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

  /// Best-effort check of whether the CURRENTLY logged-in account's
  /// Supabase email is confirmed. Never blocks anything — local login
  /// stays fully independent of this. Returns null if it can't be
  /// determined (offline, no session, etc.) rather than assuming either way.
  bool? get isEmailConfirmed {
    final supaUser = _supabase.auth.currentUser;
    if (supaUser == null) return null;
    return supaUser.emailConfirmedAt != null;
  }

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

  static const _webResetUrl = 'https://fuelflow-dashboard-rho.vercel.app/reset-password'; // fill in your real deployed URL

  Future<void> requestAdminPasswordReset(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email.trim().toLowerCase(), redirectTo: _webResetUrl);
    } catch (e) {
      throw Exception('Could not send reset email. Check your internet connection.');
    }
  }

  /// After resetting on the web dashboard, verifies the new password
  /// against Supabase and updates this device's local hash to match.
  Future<void> syncPasswordAfterCloudReset({required String email, required String newPassword}) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      await _supabase.auth.signInWithPassword(email: cleanEmail, password: newPassword);
    } catch (e) {
      throw Exception('Password not recognized by the cloud yet. Make sure you reset it on the web dashboard first.');
    }

    final local = await repo.fetchByEmail(cleanEmail);
    if (local == null) throw Exception('No local account found for this email on this device');

    final salt = _generateSalt();
    final hash = _hash(newPassword, salt);
    await repo.updatePassword(local.id, hash, salt);
  }

  Future<void> resetManagerPassword({required String userId, required String newPassword}) async {
    if (!isOwner) throw Exception('Only the Admin can reset a Manager password');
    if (newPassword.length < 6) throw Exception('Password must be at least 6 characters');
    final salt = _generateSalt();
    final hash = _hash(newPassword, salt);
    await repo.updatePassword(userId, hash, salt);
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

  Future<bool> hasAnyLocalUser() => repo.hasAnyUser();

  String _generateToken() {
    final rand = Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous chars
    final code = List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'MGR-$code';
  }

  /// Owner-only. Requires internet — writes the token to Supabase so a
  /// Manager on a different device can validate it before she has any
  /// session of her own.
  Future<String> generateManagerToken() async {
    if (!isOwner) throw Exception('Only the Owner can generate manager tokens');
    final token = _generateToken();
    try {
      await _supabase.from('manager_tokens').insert({'token': token, 'status': 'unused'});
    } catch (e) {
      throw Exception('Could not generate token. Check your internet connection.');
    }
    return token;
  }

  Future<List<Map<String, dynamic>>> fetchManagerTokens() async {
    if (!isOwner) throw Exception('Only the Owner can view manager tokens');
    final rows = await _supabase.from('manager_tokens').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Used on a Manager's OWN separate device, which has no local Owner or
  /// Manager account yet. Validates the token, registers this Manager's
  /// own Supabase identity (the one online step), marks the token used,
  /// then creates her local account for offline login from now on.
  Future<UserRecord> registerManagerWithToken({
    required String token,
    required String email,
    required String password,
    String? name,
  }) async {
    final cleanToken = token.trim().toUpperCase();
    final cleanEmail = email.trim().toLowerCase();

    if (cleanToken.isEmpty) throw Exception('Enter the manager token given by your Owner');
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) throw Exception('Enter a valid email');
    if (password.length < 6) throw Exception('Password must be at least 6 characters');

    Map<String, dynamic> tokenRow;
    try {
      final rows = await _supabase.from('manager_tokens').select().eq('token', cleanToken).limit(1);
      if (rows.isEmpty) throw Exception('Invalid token. Check the code and try again.');
      tokenRow = rows.first as Map<String, dynamic>;
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Could not reach the cloud to verify this token. Check your internet connection.');
    }

    if (tokenRow['status'] != 'unused') {
      throw Exception('This token has already been used. Ask your Owner for a new one.');
    }

    await _registerWithSupabase(cleanEmail, password);

    await _supabase.from('manager_tokens').update({
      'status': 'used',
      'used_at': DateTime.now().toIso8601String(),
      'used_by_email': cleanEmail,
    }).eq('token', cleanToken);

    final existing = await repo.fetchByEmail(cleanEmail);
    if (existing != null) throw Exception('An account with this email already exists on this device');

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
    _currentUser = user;
    notifyListeners();
    return user;
  }
}