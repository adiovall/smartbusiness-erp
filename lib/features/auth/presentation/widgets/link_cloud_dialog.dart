import 'package:flutter/material.dart';
import '../../../../core/services/service_registry.dart';
import '../../../../core/utils/friendly_error.dart';

const _panelBg = Color(0xFF0f172a);
const _textPrimary = Color(0xFFE5E7EB);
const _textSecondary = Color(0xFF9CA3AF);
const _inputBorder = Color(0xFF334155);

/// Registers the currently logged-in Owner account with Supabase, for
/// accounts created before cloud registration existed, or when this
/// device's cloud session is missing. Owner re-enters their own local
/// password (not a new one) to confirm identity before linking.
class LinkCloudDialog extends StatefulWidget {
  const LinkCloudDialog({super.key});

  @override
  State<LinkCloudDialog> createState() => _LinkCloudDialogState();
}

class _LinkCloudDialogState extends State<LinkCloudDialog> {
  final passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await Services.auth.linkCurrentAccountToCloud(password: passCtrl.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = Services.auth.currentUser?.email ?? '';
    return Dialog(
      backgroundColor: _panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _inputBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Link Account to Cloud',
                  style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                "This registers $email with the cloud, so this device "
                "can send data. You'll need internet for this one step.",
                style: const TextStyle(color: _textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passCtrl,
                obscureText: _obscure,
                style: const TextStyle(color: _textPrimary),
                decoration: InputDecoration(
                  labelText: 'Confirm your password',
                  labelStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.04),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                        color: _textSecondary, size: 18),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: _inputBorder),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.green),
                    borderRadius: BorderRadius.circular(8),
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
                        : const Text('Link to Cloud'),
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