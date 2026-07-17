import 'package:flutter/material.dart';

import '../../../../core/services/service_registry.dart';
import '../../../fuel/presentation/screens/fuel_admin_final.dart';
import 'entry_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    Services.auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    Services.auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!Services.auth.isLoggedIn) {
      return const EntryScreen();
    }
    return const FuelAdminFinal();
  }
}