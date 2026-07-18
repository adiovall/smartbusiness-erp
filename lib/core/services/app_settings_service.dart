import 'package:flutter/foundation.dart';
import '../../features/fuel/repositories/app_settings_repo.dart';

class AppSettingsService with ChangeNotifier {
  final AppSettingsRepo repo;
  AppSettingsService({required this.repo});

  static const _kStationName = 'station_name';
  static const _kLogoPath = 'logo_path';

  String stationName = 'FuelFlow ERP';
  String? logoPath;

  Future<void> loadFromDb() async {
    stationName = await repo.get(_kStationName) ?? 'FuelFlow ERP';
    logoPath = await repo.get(_kLogoPath);
    notifyListeners();
  }

  Future<void> setStationName(String name) async {
    final clean = name.trim().isEmpty ? 'FuelFlow ERP' : name.trim();
    await repo.set(_kStationName, clean);
    stationName = clean;
    notifyListeners();
  }

  Future<void> setLogoPath(String path) async {
    await repo.set(_kLogoPath, path);
    logoPath = path;
    notifyListeners();
  }

  Future<void> clearLogo() async {
    await repo.set(_kLogoPath, '');
    logoPath = null;
    notifyListeners();
  }
}