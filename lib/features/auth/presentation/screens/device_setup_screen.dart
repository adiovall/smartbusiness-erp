import 'package:flutter/material.dart';
import 'create_owner_screen.dart';
import 'register_manager_screen.dart';

const _panelBg = Color(0xFF0f172a);
const _cardBg = Color(0xFF111827);
const _textPrimary = Color(0xFFE5E7EB);
const _textSecondary = Color(0xFF9CA3AF);
const _inputBorder = Color(0xFF334155);

class DeviceSetupScreen extends StatefulWidget {
  final VoidCallback onDone;
  const DeviceSetupScreen({super.key, required this.onDone});

  @override
  State<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends State<DeviceSetupScreen> {
  bool? _isNewOwner;

  @override
  Widget build(BuildContext context) {
    if (_isNewOwner == true) {
      return CreateOwnerScreen(onCreated: widget.onDone);
    }
    if (_isNewOwner == false) {
      return RegisterManagerScreen(
        onRegistered: widget.onDone,
        onBack: () => setState(() => _isNewOwner = null),
      );
    }

    return Scaffold(
      backgroundColor: _panelBg,
      body: Center(
        child: Container(
          width: 420,
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
              const Text('Welcome to FuelFlow ERP',
                  style: TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                "Is this the first device for this station, or are you "
                "a Manager joining with a token from your Owner?",
                style: TextStyle(color: _textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => setState(() => _isNewOwner = true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Set Up as Owner (first device)'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => setState(() => _isNewOwner = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                  child: const Text('I Have a Manager Token'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}