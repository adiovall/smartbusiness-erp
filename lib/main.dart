// // lib/main.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'features/fuel/presentation/screens/fuel_admin_final.dart';

void main() {
  // ✅ REQUIRED FOR SQLITE ON WINDOWS
  if (Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const SmartBusinessApp());
}

class SmartBusinessApp extends StatelessWidget {
  const SmartBusinessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartBusiness ERP',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Segoe UI',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0f172a),
      ),
      home: const FuelAdminFinal(),
    );
  }
}
