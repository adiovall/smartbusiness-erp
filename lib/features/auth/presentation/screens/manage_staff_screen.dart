import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/models/user_record.dart';
import '../../../../core/services/service_registry.dart';

const _panelBg = Color(0xFF0b1220);
const _cardBg = Color(0xFF111827);
const _textPrimary = Color(0xFFE5E7EB);
const _textSecondary = Color(0xFF9CA3AF);
const _inputBorder = Color(0xFF334155);

class ManageStaffScreen extends StatefulWidget {
  final VoidCallback onBack;
  const ManageStaffScreen({super.key, required this.onBack});

  @override
  State<ManageStaffScreen> createState() => _ManageStaffScreenState();
}

class _ManageStaffScreenState extends State<ManageStaffScreen> {
  List<UserRecord> _staff = [];
  bool _loading = true;

  List<Map<String, dynamic>> _tokens = [];
  bool _loadingTokens = true;

  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _loadTokens();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final staff = await Services.auth.fetchAllStaff();
    if (!mounted) return;
    setState(() {
      _staff = staff;
      _loading = false;
    });
  }

  Future<void> _loadTokens() async {
    setState(() => _loadingTokens = true);
    try {
      final tokens = await Services.auth.fetchManagerTokens();
      if (!mounted) return;
      setState(() {
        _tokens = tokens;
        _loadingTokens = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingTokens = false);
    }
  }

  Future<void> _createManager() async {
    setState(() {
      _error = null;
      _creating = true;
    });
    try {
      await Services.auth.createManagerAccount(
        email: emailCtrl.text,
        password: passCtrl.text,
        name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
      );
      nameCtrl.clear();
      emailCtrl.clear();
      passCtrl.clear();
      await _load();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _generateToken() async {
    try {
      final token = await Services.auth.generateManagerToken();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: _cardBg,
          title: const Text('Manager Token Generated', style: TextStyle(color: _textPrimary)),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(token,
                  style: const TextStyle(color: Colors.orange, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy, color: _textSecondary, size: 18),
                tooltip: 'Copy',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: token));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Token copied'), backgroundColor: Colors.green),
                  );
                },
              ),
            ],
          ),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ],
        ),
      );
      await _loadTokens();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _deleteStaff(UserRecord u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardBg,
        title: const Text('Remove account?', style: TextStyle(color: _textPrimary)),
        content: Text('Remove ${u.email}? They will no longer be able to log in.',
            style: const TextStyle(color: _textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await Services.auth.deleteStaff(u.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        isDense: true,
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _inputBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.green),
          borderRadius: BorderRadius.circular(8),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _panelBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f172a),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
        title: const Text('Manage Staff'),
      ),
      body: (_loading || _loadingTokens)
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _inputBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _generateToken,
                            icon: const Icon(Icons.vpn_key, size: 16),
                            label: const Text('Generate Token for a Different Device'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange)),
                          ),
                          const SizedBox(height: 16),
                          const Text('Add Manager (this device)',
                              style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 16),
                          TextField(controller: nameCtrl, style: const TextStyle(color: _textPrimary), decoration: _dec('Name (optional)')),
                          const SizedBox(height: 10),
                          TextField(controller: emailCtrl, style: const TextStyle(color: _textPrimary), decoration: _dec('Email')),
                          const SizedBox(height: 10),
                          TextField(controller: passCtrl, obscureText: true, style: const TextStyle(color: _textPrimary), decoration: _dec('Temporary Password')),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _creating ? null : _createManager,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              child: Text(_creating ? 'Creating...' : 'Create Manager Account'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _inputBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('All Accounts',
                              style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 12),
                          Expanded(
                            flex: 3,
                            child: _staff.isEmpty
                                ? const Center(child: Text('No accounts yet', style: TextStyle(color: _textSecondary)))
                                : ListView.separated(
                                    itemCount: _staff.length,
                                    separatorBuilder: (_, __) => const Divider(color: _inputBorder),
                                    itemBuilder: (_, i) {
                                      final u = _staff[i];
                                      final isSelf = u.id == Services.auth.currentUser?.id;
                                      return ListTile(
                                        title: Text(u.name?.isNotEmpty == true ? u.name! : u.email,
                                            style: const TextStyle(color: _textPrimary)),
                                        subtitle: Text('${u.email} • ${u.role == 'owner' ? 'Admin' : 'Manager'}',
                                            style: const TextStyle(color: _textSecondary, fontSize: 12)),
                                        trailing: u.isOwner
                                            ? const Text('—', style: TextStyle(color: _textSecondary))
                                            : IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                                onPressed: isSelf ? null : () => _deleteStaff(u),
                                              ),
                                      );
                                    },
                                  ),
                          ),
                          const Divider(color: _inputBorder, height: 24),
                          const Text('Manager Tokens',
                              style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          const Text('Generated for Managers registering on their own device',
                              style: TextStyle(color: _textSecondary, fontSize: 11)),
                          const SizedBox(height: 10),
                          Expanded(
                            flex: 2,
                            child: _tokens.isEmpty
                                ? const Center(child: Text('No tokens generated yet', style: TextStyle(color: _textSecondary)))
                                : ListView.separated(
                                    itemCount: _tokens.length,
                                    separatorBuilder: (_, __) => const Divider(color: _inputBorder),
                                    itemBuilder: (_, i) {
                                      final t = _tokens[i];
                                      final isUsed = t['status'] == 'used';
                                      return ListTile(
                                        dense: true,
                                        title: Text(t['token'] as String,
                                            style: const TextStyle(color: _textPrimary, fontFamily: 'monospace', fontSize: 13)),
                                        subtitle: isUsed
                                            ? Text('Accepted by ${t['used_by_email']}',
                                                style: const TextStyle(color: Colors.greenAccent, fontSize: 11))
                                            : const Text('Waiting for a Manager to register',
                                                style: TextStyle(color: Colors.orange, fontSize: 11)),
                                        trailing: isUsed
                                            ? const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18)
                                            : IconButton(
                                                icon: const Icon(Icons.copy, color: _textSecondary, size: 16),
                                                tooltip: 'Copy',
                                                onPressed: () {
                                                  Clipboard.setData(ClipboardData(text: t['token'] as String));
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Token copied'), backgroundColor: Colors.green),
                                                  );
                                                },
                                              ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}