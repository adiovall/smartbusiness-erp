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

  // _registerWithSupabase gains an optional metadata param
  Future<String> _registerWithSupabase(String email, String password, {Map<String, dynamic>? data}) async {
    try {
      final response = await _supabase.auth.signUp(email: email, password: password, data: data);
      final id = response.user?.id;
      if (id == null) throw Exception('Cloud registration did not return a user id.');
      return id;
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

  /// Creates an Owner (Admin) account. Station identity for an Owner is
  /// simply their own Supabase auth uid — no separate stations table
  /// needed. station_members gets one row so RLS lookups stay uniform
  /// across Owners and Managers.
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

    final supabaseUserId = await _registerWithSupabase(cleanEmail, password, data: {'role': 'owner'});

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

  static const _webResetUrl = 'https://fuelflow-dashboard-rho.vercel.app/reset-password';

  Future<void> requestAdminPasswordReset(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email.trim().toLowerCase(), redirectTo: _webResetUrl);
    } catch (e) {
      throw Exception('Could not send reset email. Check your internet connection.');
    }
  }

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

    // Manager accounts created this way (by an Owner already logged in
    // on this same device) are local-only — no separate Supabase
    // identity, no station_members row needed, since Send Data on this
    // device already uses the Owner's own cloud session/station.

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

  Future<void> linkCurrentAccountToCloud({required String password}) async {
    if (!isOwner) throw Exception('Only the Owner account can be linked to the cloud');
    final user = _currentUser;
    if (user == null) throw Exception('Not logged in');

    final hash = _hash(password, user.salt);
    if (hash != user.passwordHash) {
      throw Exception('Incorrect password');
    }

    final supabaseUserId = await _registerWithSupabase(user.email, password);

    try {
      await _supabase.from('station_members').insert({
        'user_id': supabaseUserId,
        'station_id': supabaseUserId,
        'role': 'owner',
      });
    } catch (e) {
      throw Exception('Linked to the cloud but station setup failed. Contact support.');
    }
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
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final code = List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'MGR-$code';
  }

  /// Owner-only. Stamps the token with the Owner's own uid as its
  /// station_id, so a Manager registering with this token later ends up
  /// in the right station.
  Future<String> generateManagerToken() async {
    if (!isOwner) throw Exception('Only the Owner can generate manager tokens');
    final stationId = _supabase.auth.currentUser?.id;
    if (stationId == null) throw Exception('No active cloud session. Sign in to the cloud first.');

    final token = _generateToken();
    try {
      await _supabase.from('manager_tokens').insert({
        'token': token,
        'status': 'unused',
        'station_id': stationId,
      });
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

  /// Used on a Manager's OWN separate device. Validates the token,
  /// registers her own Supabase identity, joins her to her Owner's
  /// station via station_members, marks the token used, then creates
  /// her local account for offline login from now on.
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

    final stationId = tokenRow['station_id'] as String?;
    if (stationId == null) {
      throw Exception('This token is missing station info. Ask your Owner to generate a new one.');
    }

    final managerUserId = await _registerWithSupabase(
      cleanEmail,
      password,
      data: {'role': 'manager', 'station_id': stationId},
    );
    // station_members row for this Manager is created automatically by
    // the on_auth_user_created Postgres trigger, using the station_id
    // passed above as signup metadata — no client write needed here.

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

  /// Resolves the current cloud session's station_id, for use by
  /// SyncService / ConfigSyncService / SubscriptionService when
  /// stamping or scoping cloud reads and writes.
  Future<String?> resolveStationId() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final rows = await _supabase.from('station_members').select('station_id').eq('user_id', uid).limit(1);
      if (rows.isEmpty) return null;
      return rows.first['station_id'] as String?;
    } catch (_) {
      return null;
    }
  }
}