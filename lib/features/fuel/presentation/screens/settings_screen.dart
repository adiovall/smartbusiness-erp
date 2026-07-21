import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../../core/services/service_registry.dart';
import '../../../auth/presentation/widgets/link_cloud_dialog.dart';

const _panelBg = Color(0xFF0b1220);
const _cardBg = Color(0xFF111827);
const _textPrimary = Color(0xFFE5E7EB);
const _textSecondary = Color(0xFF9CA3AF);
const _inputBorder = Color(0xFF334155);

class SettingsScreen extends StatefulWidget {
  final VoidCallback onBack;
  const SettingsScreen({super.key, required this.onBack});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController nameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: Services.appSettings.stationName);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    setState(() => _saving = true);
    await Services.appSettings.setStationName(nameCtrl.text);
    await Services.configSync.pushStationConfig();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Station name saved'), backgroundColor: Colors.green),
    );
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final ext = p.extension(result.files.single.path!);
    final dest = p.join(dir.path, 'station_logo$ext');

    // Evict the OLD path from Flutter's image cache before overwriting —
    // otherwise FileImage keeps showing stale cached bytes for this same
    // path even after the file on disk has changed.
    final oldPath = Services.appSettings.logoPath;
    if (oldPath != null) {
      await FileImage(File(oldPath)).evict();
    }

    await File(result.files.single.path!).copy(dest);
    await Services.appSettings.setLogoPath(dest);
    await Services.configSync.pushStationConfig();

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = Services.auth.isOwner;
    final logoPath = Services.appSettings.logoPath;

    return Scaffold(
      backgroundColor: _panelBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f172a),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
        title: const Text('Settings'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 460,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _inputBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
               if (isAdmin) ...[
                  Builder(builder: (context) {
                    final confirmed = Services.auth.isEmailConfirmed;
                    if (confirmed == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Icon(
                            confirmed ? Icons.verified : Icons.warning_amber_rounded,
                            color: confirmed ? Colors.greenAccent : Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            confirmed ? 'Email verified' : 'Email not verified — check your inbox',
                            style: TextStyle(color: confirmed ? Colors.greenAccent : Colors.orange, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const Text('Station Branding',
                    style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white.withOpacity(0.06),
                        backgroundImage: logoPath != null ? FileImage(File(logoPath)) : null,
                        child: logoPath == null
                            ? const Icon(Icons.local_gas_station, color: _textSecondary, size: 32)
                            : null,
                      ),
                      const SizedBox(height: 10),
                      if (isAdmin)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(onPressed: _pickLogo, child: const Text('Change Logo')),
                            if (logoPath != null)
                              TextButton(
                                onPressed: () async {
                                  await Services.appSettings.clearLogo();
                                  if (mounted) setState(() {});
                                },
                                child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  enabled: isAdmin,
                  style: const TextStyle(color: _textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Station Name',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: _inputBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.green),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveName,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: Text(_saving ? 'Saving...' : 'Save Station Name'),
                    ),
                  ),
                ],
                if (isAdmin) ...[
                  const Divider(color: _inputBorder, height: 40),
                  const Text('Cloud',
                      style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => showDialog(context: context, builder: (_) => const LinkCloudDialog()),
                    icon: const Icon(Icons.cloud_sync, size: 16),
                    label: const Text('Link This Account to Cloud'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}