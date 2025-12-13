// lib/features/fuel/presentation/widgets/entry_tabs/settlement_tab.dart
import 'package:flutter/material.dart';

class SettlementTab extends StatelessWidget {
  final VoidCallback onSubmitted;
  const SettlementTab({super.key, required this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [Expanded(child: DropdownButtonFormField(items: const [], onChanged: null, decoration: const InputDecoration(labelText: 'Supplier'))), const SizedBox(width: 12), Expanded(child: DropdownButtonFormField(items: const [], onChanged: null, decoration: const InputDecoration(labelText: 'Fuel Type')))]),
        const SizedBox(height: 12),
        DropdownButtonFormField(items: const [], onChanged: null, decoration: const InputDecoration(labelText: 'Source')),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Sales Amount (₦)'))), const SizedBox(width: 12), Expanded(child: TextField(decoration: const InputDecoration(labelText: 'External Amount (₦)')))]),
        const SizedBox(height: 12),
        const Align(alignment: Alignment.centerRight, child: Text('Total Amount (₦): 0.00', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        const SizedBox(height: 20),

        const Text('Supplier Debts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        DataTable(columns: const [DataColumn(label: Text('SN')), DataColumn(label: Text('Supplier')), DataColumn(label: Text('Fuel Type')), DataColumn(label: Text('Debt (₦)')), DataColumn(label: Text('Status'))], rows: const [
          DataRow(cells: [DataCell(Text('1')), DataCell(Text('onyis fuel')), DataCell(Text('Cooking Gas (LPG)')), DataCell(Text('₦50,000.00')), DataCell(Text('Pending', style: TextStyle(color: Colors.orange)))]),
          DataRow(cells: [DataCell(Text('2')), DataCell(Text('val')), DataCell(Text('Cooking Gas (LPG)')), DataCell(Text('₦500,000.00')), DataCell(Text('Pending', style: TextStyle(color: Colors.orange)))])
        ]),

        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed: onSubmitted, icon: const Icon(Icons.payment), label: const Text('Submit Settlement'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue))),
      ]),
    );
  }
}