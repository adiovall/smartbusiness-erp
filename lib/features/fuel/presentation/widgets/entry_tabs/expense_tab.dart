// lib/features/fuel/presentation/widgets/entry_tabs/expense_tab.dart
import 'package:flutter/material.dart';

class ExpenseTab extends StatefulWidget {
  final VoidCallback onSubmitted;
  const ExpenseTab({super.key, required this.onSubmitted});
  @override State<ExpenseTab> createState() => _ExpenseTabState();
}

class _ExpenseTabState extends State<ExpenseTab> {
  final categories = ['Maintenance', 'Salary', 'Generator Fuel', 'Misc'];
  String category = 'Maintenance';
  final amount = TextEditingController(), note = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          Expanded(child: _dropdown('Category', category, categories, (v) => setState(() => category = v!))),
          const SizedBox(width: 12),
          ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Add Category')),
        ]),
        const SizedBox(height: 12),
        _field('Amount (₦)', amount),
        const SizedBox(height: 12),
        TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Note', hintText: 'Enter expense details...')),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed: () { widget.onSubmitted(); }, icon: const Icon(Icons.save), label: const Text('Record Expense'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red))),
        const SizedBox(height: 20),
        const Text("Today's Expenses", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const Text('No expenses recorded for today.', style: TextStyle(color: Colors.grey)),
      ]),
    );
  }

  Widget _dropdown(String l, String v, List<String> i, Function(String?) f) => DropdownButtonFormField<String>(value: v, decoration: InputDecoration(labelText: l), items: i.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: f);
  Widget _field(String l, TextEditingController c) => TextField(controller: c, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l));
}