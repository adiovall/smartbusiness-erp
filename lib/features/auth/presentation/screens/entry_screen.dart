import 'package:flutter/material.dart';
import '../../../../core/services/service_registry.dart';
import 'create_owner_screen.dart';
import 'register_manager_screen.dart';
import '../widgets/admin_forgot_password_dialog.dart';

const _panelBg = Color(0xFF0f172a);
const _cardBg = Color(0xFF111827);
const _textPrimary = Color(0xFFE5E7EB);
const _textSecondary = Color(0xFF9CA3AF);
const _inputBorder = Color(0xFF334155);

enum _Door { manager, admin }

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  _Door _door = _Door.manager;
  bool _managerRegisterMode = false;
  bool _adminCreateMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _panelBg,
      body: Stack(
        children: [
          Center(
            child: _door == _Door.manager
                ? (_managerRegisterMode
                    ? RegisterManagerScreen(
                        onRegistered: () {},
                        onBack: () => setState(() => _managerRegisterMode = false),
                      )
                    : _ManagerLoginPanel(
                        onSwitchToRegister: () => setState(() => _managerRegisterMode = true),
                      ))
                : (_adminCreateMode
                    ? CreateOwnerScreen(onCreated: () {})
                    : _AdminLoginPanel(
                        onSwitchToCreate: () => setState(() => _adminCreateMode = true),
                      )),
          ),
          Positioned(
            top: 20,
            right: 24,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _door = _door == _Door.manager ? _Door.admin : _Door.manager;
                _managerRegisterMode = false;
                _adminCreateMode = false;
              }),
              icon: Icon(
                _door == _Door.manager ? Icons.admin_panel_settings : Icons.person,
                size: 18,
                color: _textSecondary,
              ),
              label: Text(
                _door == _Door.manager ? 'Admin' : 'Manager',
                style: const TextStyle(color: _textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagerLoginPanel extends StatefulWidget {
  final VoidCallback onSwitchToRegister;
  const _ManagerLoginPanel({required this.onSwitchToRegister});

  @override
  State<_ManagerLoginPanel> createState() => _ManagerLoginPanelState();
}

class _ManagerLoginPanelState extends State<_ManagerLoginPanel> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

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
      final user = await Services.auth.login(email: emailCtrl.text, password: passCtrl.text);
      if (user == null) {
        setState(() => _error = 'Incorrect email or password');
        return;
      }
      if (!user.isOwner) return;
      Services.auth.logout();
      setState(() => _error = 'This is an Admin account. Use the Admin button (top right) to sign in.');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
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
    return Container(
      width: 380,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _inputBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset('assets/images/fuelflow_logo.png', width: 64, height: 64),
          const SizedBox(height: 10),
          const Text('FuelFlow ERP',
              style: TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Manager Sign In', style: TextStyle(color: _textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
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
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: _textSecondary, size: 18),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
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
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Sign In'),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: widget.onSwitchToRegister,
              child: const Text('Have a token? Register', style: TextStyle(color: Colors.orange, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminLoginPanel extends StatefulWidget {
  final VoidCallback onSwitchToCreate;
  const _AdminLoginPanel({required this.onSwitchToCreate});

  @override
  State<_AdminLoginPanel> createState() => _AdminLoginPanelState();
}

class _AdminLoginPanelState extends State<_AdminLoginPanel> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

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
      final user = await Services.auth.login(email: emailCtrl.text, password: passCtrl.text);
      if (user == null) {
        setState(() => _error = 'Incorrect email or password');
        return;
      }
      if (user.isOwner) return;
      Services.auth.logout();
      setState(() => _error = 'This is a Manager account. Use the Manager button (top right) to sign in.');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
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
          borderSide: const BorderSide(color: Colors.orange),
          borderRadius: BorderRadius.circular(8),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _inputBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset('assets/images/fuelflow_logo.png', width: 64, height: 64),
          const SizedBox(height: 10),
          const Text('FuelFlow ERP',
              style: TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Admin Sign In', style: TextStyle(color: _textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
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
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: _textSecondary, size: 18),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Sign In as Admin'),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: widget.onSwitchToCreate,
              child: const Text('First time? Create Admin Account', style: TextStyle(color: Colors.orange, fontSize: 12)),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => showDialog(context: context, builder: (_) => const AdminForgotPasswordDialog()),
              child: const Text('Forgot password?', style: TextStyle(color: _textSecondary, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}