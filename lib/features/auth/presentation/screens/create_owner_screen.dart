import 'package:flutter/material.dart';
import '../../../../core/services/service_registry.dart';
import '../../../../core/utils/friendly_error.dart';

const _panelBg = Color(0xFF0f172a);
const _cardBg = Color(0xFF111827);
const _textPrimary = Color(0xFFE5E7EB);
const _textSecondary = Color(0xFF9CA3AF);
const _inputBorder = Color(0xFF334155);

class CreateOwnerScreen extends StatefulWidget {
  final VoidCallback onCreated;
  const CreateOwnerScreen({super.key, required this.onCreated});

  @override
  State<CreateOwnerScreen> createState() => _CreateOwnerScreenState();
}

class _CreateOwnerScreenState extends State<CreateOwnerScreen> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    if (passCtrl.text != confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() => _loading = true);
    try {
      await Services.auth.createOwnerAccount(
        email: emailCtrl.text,
        password: passCtrl.text,
        name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
      );
      if (mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: _cardBg,
            title: const Text('Check Your Email', style: TextStyle(color: _textPrimary, fontSize: 16)),
            content: const Text(
              "We've sent a confirmation link to your email. Verifying it "
              "isn't required to use the app right now, but it's needed if "
              "you ever reset your password through email.",
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
            actions: [
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
            ],
          ),
        );
      }
      widget.onCreated();
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
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _inputBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Welcome to FuelFlow ERP',
                    style: TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text(
                  "Let's set up your Admin account for your fuel station. ",
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: _textPrimary),
                  decoration: _dec('Your Name (optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  style: const TextStyle(color: _textPrimary),
                  decoration: _dec('Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: _textPrimary),
                  decoration: _dec('Password').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                          color: _textSecondary, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: _textPrimary),
                  decoration: _dec('Confirm Password'),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: _loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Create Admin Account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}