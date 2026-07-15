import 'package:flutter/material.dart';

import '../../../../core/services/service_registry.dart';
import '../../../fuel/presentation/screens/fuel_admin_final.dart';
import 'create_owner_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _needsOwnerAccount = false;

  @override
  void initState() {
    super.initState();
    Services.auth.addListener(_onAuthChanged);
    _check();
  }

  @override
  void dispose() {
    Services.auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _check() async {
    final hasOwner = await Services.auth.hasAnyOwner();
    if (!mounted) return;
    setState(() {
      _needsOwnerAccount = !hasOwner;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0b1220),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_needsOwnerAccount) {
      return CreateOwnerScreen(
        onCreated: () {
          if (mounted) setState(() => _needsOwnerAccount = false);
        },
      );
    }

    if (!Services.auth.isLoggedIn) {
      return const LoginScreen();
    }

    return const FuelAdminFinal();
  }
}