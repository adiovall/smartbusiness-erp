import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class SubscriptionStatus {
  final String plan;
  final DateTime expiresAt;
  bool get isActive => DateTime.now().isBefore(expiresAt);
  SubscriptionStatus({required this.plan, required this.expiresAt});
}

class SubscriptionService {
  final SupabaseClient _client = Supabase.instance.client;
  final AuthService authService;

  SubscriptionService({required this.authService});

  SubscriptionStatus? _cached;
  SubscriptionStatus? get cached => _cached;

  /// Real check, called right before Send Data pushes to the cloud —
  /// this is already the one moment the app requires internet, so it's
  /// the natural place to enforce this without adding a new online
  /// dependency anywhere else. Scoped by station so each station's
  /// subscription is independent.
  Future<SubscriptionStatus?> checkActive() async {
    try {
      final stationId = await authService.resolveStationId();
      if (stationId == null) return _cached;

      final rows = await _client.from('subscription').select().eq('station_id', stationId).limit(1);
      if (rows.isEmpty) return null;
      final row = rows.first;
      final status = SubscriptionStatus(
        plan: row['plan'] as String,
        expiresAt: DateTime.parse(row['expires_at'] as String),
      );
      _cached = status;
      return status;
    } catch (_) {
      return _cached;
    }
  }
}