import 'package:flutter/material.dart';
import '../../../../core/services/service_registry.dart';
import '../../../../core/utils/friendly_error.dart';

const _panelBg = Color(0xFF0f172a);
const _textPrimary = Color(0xFFE5E7EB);
const _textSecondary = Color(0xFF9CA3AF);
const _inputBorder = Color(0xFF334155);

/// Shown only when Send Data can't find an active Supabase session.
/// One-time cloud re-auth; never blocks or replaces daily local login.
class CloudSignInDialog extends StatefulWidget {
  const CloudSignInDialog({super.key});

  @override
  State<CloudSignInDialog> createState() => _CloudSignInDialogState();
}

class _CloudSignInDialogState extends State<CloudSignInDialog> {
  late final TextEditingController emailCtrl;
  final passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    emailCtrl = TextEditingController(text: Services.auth.currentUser?.email ?? '');
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await Services.auth.signInToCloud(email: emailCtrl.text, password: passCtrl.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
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
    return Dialog(
      backgroundColor: _panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _inputBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cloud Sign-In Required',
                  style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                "This device's connection to the cloud needs to be "
                "refreshed before sending data. Sign in once to continue.",
                style: TextStyle(color: _textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                style: const TextStyle(color: _textPrimary),
                decoration: _dec('Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                obscureText: _obscure,
                style: const TextStyle(color: _textPrimary),
                decoration: _dec('Password').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                        color: _textSecondary, size: 18),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: _loading
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Sign In'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}