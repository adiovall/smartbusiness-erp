// lib/features/fuel/presentation/widgets/entry_tabs/external_payments_tab.dart
import 'package:flutter/material.dart';

class ExternalPaymentsTab extends StatelessWidget {
  const ExternalPaymentsTab({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const Text('External Payments', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        DataTable(columns: const [
          DataColumn(label: Text('Source')),
          DataColumn(label: Text('Supplier')),
          DataColumn(label: Text('Fuel Type')),
          DataColumn(label: Text('Amount (₦)')),
          DataColumn(label: Text('Date')),
        ], rows: const []),
      ]),
    );
  }
}