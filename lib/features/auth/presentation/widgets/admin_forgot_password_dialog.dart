import 'package:flutter/material.dart';
import '../../../../core/services/service_registry.dart';

const _cardBg = Color(0xFF111827);
const _textPrimary = Color(0xFFE5E7EB);
const _textSecondary = Color(0xFF9CA3AF);
const _inputBorder = Color(0xFF334155);

class AdminForgotPasswordDialog extends StatefulWidget {
  const AdminForgotPasswordDialog({super.key});
  @override
  State<AdminForgotPasswordDialog> createState() => _AdminForgotPasswordDialogState();
}

class _AdminForgotPasswordDialogState extends State<AdminForgotPasswordDialog> {
  bool _step2 = false;
  final emailCtrl = TextEditingController();
  final newPassCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _info;

  Future<void> _sendReset() async {
    setState(() { _loading = true; _error = null; });
    try {
      await Services.auth.requestAdminPasswordReset(emailCtrl.text);
      setState(() { _info = 'Reset link sent. Check your email.'; _step2 = true; });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sync() async {
    setState(() { _loading = true; _error = null; });
    try {
      await Services.auth.syncPasswordAfterCloudReset(email: emailCtrl.text, newPassword: newPassCtrl.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary),
        filled: true, fillColor: Colors.white.withOpacity(0.04), isDense: true,
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _inputBorder), borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.orange), borderRadius: BorderRadius.circular(8)),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0f172a),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _inputBorder)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_step2 ? 'Set New Password' : 'Reset Admin Password',
                style: const TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(controller: emailCtrl, style: const TextStyle(color: _textPrimary), decoration: _dec('Email')),
            if (_step2) ...[
              const SizedBox(height: 10),
              TextField(controller: newPassCtrl, obscureText: true, style: const TextStyle(color: _textPrimary),
                  decoration: _dec('New password (set on web dashboard)')),
            ],
            if (_info != null) ...[const SizedBox(height: 10), Text(_info!, style: const TextStyle(color: Colors.greenAccent, fontSize: 12))],
            if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))],
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _loading ? null : (_step2 ? _sync : _sendReset),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: Text(_loading ? '...' : (_step2 ? 'Sync' : 'Send Reset Link')),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}