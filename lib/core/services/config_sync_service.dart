import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tank_state.dart';
import 'auth_service.dart';
import 'service_registry.dart';

/// Best-effort push/pull of shared config (station branding, tank
/// state, pump layout) so Admin's and Manager's separate devices stay
/// in sync — scoped per station via AuthService.resolveStationId().
/// All calls swallow errors silently — offline is normal, and the
/// next successful pull/push catches up.
class ConfigSyncService {
  final SupabaseClient _client = Supabase.instance.client;
  final AuthService authService;

  ConfigSyncService({required this.authService});

  Future<void> pushStationConfig() async {
    try {
      final stationId = await authService.resolveStationId();
      if (stationId == null) return;

      String? logoUrl;
      final logoPath = Services.appSettings.logoPath;
      if (logoPath != null) {
        final ext = logoPath.split('.').last;
        final storagePath = '$stationId/logo.$ext';
        await _client.storage.from('station-assets').upload(
              storagePath, File(logoPath),
              fileOptions: const FileOptions(upsert: true),
            );
        logoUrl = _client.storage.from('station-assets').getPublicUrl(storagePath);
      }
      await _client.from('station_config').upsert({
        'station_id': stationId,
        'station_name': Services.appSettings.stationName,
        if (logoUrl != null) 'logo_url': logoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> pullStationConfig() async {
    try {
      final stationId = await authService.resolveStationId();
      if (stationId == null) return;

      final rows = await _client.from('station_config').select().eq('station_id', stationId).limit(1);
      if (rows.isEmpty) return;
      final row = rows.first;
      final name = row['station_name'] as String?;
      final logoUrl = row['logo_url'] as String?;
      if (name != null) await Services.appSettings.setStationName(name);
      if (logoUrl != null) await Services.appSettings.downloadAndSetLogo(logoUrl);
    } catch (_) {}
  }

  Future<void> pushTankConfig() async {
    try {
      final stationId = await authService.resolveStationId();
      if (stationId == null) return;

      for (final t in Services.tank.allTanks) {
        await _client.from('tank_config').upsert({
          'station_id': stationId,
          'fuel_type': t.fuelType,
          'capacity': t.capacity,
          'current_level': t.currentLevel,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
  }

  Future<void> pullTankConfig() async {
    try {
      final stationId = await authService.resolveStationId();
      if (stationId == null) return;

      final rows = await _client.from('tank_config').select().eq('station_id', stationId);
      for (final r in rows) {
        await Services.tank.updateTank(TankState(
          fuelType: r['fuel_type'] as String,
          capacity: (r['capacity'] as num).toDouble(),
          currentLevel: (r['current_level'] as num).toDouble(),
        ));
      }
    } catch (_) {}
  }

  Future<void> pushPumpConfig() async {
    try {
      final stationId = await authService.resolveStationId();
      if (stationId == null) return;

      for (final p in Services.pumpConfig.pumps) {
        await _client.from('pump_config_sync').upsert({
          'station_id': stationId,
          'pump_no': p.pumpNo,
          'fuel_type': p.fuelType,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
  }

  Future<void> pullPumpConfig() async {
    try {
      final stationId = await authService.resolveStationId();
      if (stationId == null) return;

      final rows = await _client.from('pump_config_sync').select().eq('station_id', stationId);
      final map = <String, String>{for (final r in rows) r['pump_no'] as String: r['fuel_type'] as String};
      if (map.isNotEmpty) await Services.pumpConfig.saveConfig(map);
    } catch (_) {}
  }

  Future<void> pullAll() async {
    await pullStationConfig();
    await pullTankConfig();
    await pullPumpConfig();
  }
}