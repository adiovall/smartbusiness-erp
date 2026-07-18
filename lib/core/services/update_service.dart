import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_version.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String notes;
  UpdateInfo({required this.version, required this.downloadUrl, required this.notes});
}

/// Checks GitHub Releases for a newer published version. Fails silently
/// on any network error — this must never interrupt someone working
/// offline, it's purely a background check.
class UpdateService {
  static const _repo = 'adiovall/smartbusiness-erp'; // adjust if your repo name differs

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final res = await http
          .get(Uri.parse('https://api.github.com/repos/$_repo/releases/latest'))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String?) ?? '';
      final latestVersion = tag.startsWith('v') ? tag.substring(1) : tag;
      if (latestVersion.isEmpty) return null;

      if (!_isNewer(latestVersion, kAppVersion)) return null;

      final assets = (json['assets'] as List? ?? []);
      final exeAsset = assets.firstWhere(
        (a) => (a['name'] as String?)?.toLowerCase().endsWith('.exe') ?? false,
        orElse: () => null,
      );
      if (exeAsset == null) return null;

      return UpdateInfo(
        version: latestVersion,
        downloadUrl: exeAsset['browser_download_url'] as String,
        notes: (json['body'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  bool _isNewer(String a, String b) {
    final pa = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final pb = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va > vb;
    }
    return false;
  }
}