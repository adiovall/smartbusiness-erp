// lib/features/fuel/presentation/widgets/entry_tabs/expense_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/../core/services/service_registry.dart';
import '/../core/models/expense_record.dart';

const panelBg = Color(0xFF0f172a);
const panelBorder = Color(0xFF1f2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);
const inputBorder = Color(0xFF334155);

class ExpenseTab extends StatefulWidget {
  final VoidCallback onSubmitted;

  const ExpenseTab({
    super.key,
    required this.onSubmitted,
  });

  @override
  State<ExpenseTab> createState() => _ExpenseTabState();
}

class _ExpenseTabState extends State<ExpenseTab> {
  final categories = ['Maintenance', 'Salary', 'Generator Fuel', 'Misc'];
  String selectedCategory = 'Maintenance';

  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  List<ExpenseRecord> expenses = [];

  @override
  void initState() {
    super.initState();
    _loadTodayExpenses();
    // Listen for changes (e.g., from sales shortage)
    Services.expense.addListener(_refreshExpenses);
  }

  @override
  void dispose() {
    Services.expense.removeListener(_refreshExpenses);
    amountCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  void _refreshExpenses() {
    setState(() {
      expenses = Services.expense.todayExpenses;
    });
  }

  void _loadTodayExpenses() {
    setState(() {
      expenses = Services.expense.todayExpenses;
    });
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},');
  }

  Future<void> _recordExpense() async {
    final amountText = amountCtrl.text.replaceAll(',', '');
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    await Services.expense.createExpense(
      amount: amount,
      category: selectedCategory,
      comment: noteCtrl.text.trim(),
    );

    widget.onSubmitted();

    setState(() {
      expenses = Services.expense.todayExpenses;
    });

    amountCtrl.clear();
    noteCtrl.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Expense recorded: ₦${_formatAmount(amount)}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: textSecondary),
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: inputBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _numberField(String label, TextEditingController ctrl) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: _input(label),
        style: const TextStyle(color: textPrimary),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return SizedBox(
      height: 48,
      child: DropdownButtonFormField<String>(
        value: value,
        isDense: true,
        isExpanded: true,
        dropdownColor: panelBg,
        decoration: _input(label),
        items: items
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(color: textPrimary)),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalExpense = Services.expense.todayTotal;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /* TOP ROW */
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _dropdown('Category', selectedCategory, categories, (v) => setState(() => selectedCategory = v!)),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _numberField('Amount (₦)', amountCtrl),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 80,
            child: TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: _input('Note / Description'),
              style: const TextStyle(color: textPrimary),
            ),
          ),

          const SizedBox(height: 20),

          /* ACTIONS */
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    amountCtrl.clear();
                    noteCtrl.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textSecondary,
                    side: const BorderSide(color: inputBorder),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _recordExpense,
                  icon: const Icon(Icons.save),
                  label: const Text('Record'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          /* RECORDED EXPENSES */
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Expenses",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
              ),
              Text(
                'Total: ₦${_formatAmount(totalExpense)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: expenses.isEmpty
                ? const Center(
                    child: Text('No expenses recorded for today.', style: TextStyle(color: textSecondary)),
                  )
                : ListView.separated(
                    itemCount: expenses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final e = expenses[i];
                      final isLocked = e.isLocked;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isLocked ? Colors.red.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isLocked ? Colors.red : panelBorder,
                            width: isLocked ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.category,
                                    style: TextStyle(
                                      color: isLocked ? Colors.red : textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (e.comment.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        e.comment,
                                        style: const TextStyle(color: textSecondary, fontSize: 12),
                                      ),
                                    ),
                                  if (isLocked)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 6),
                                      child: Text(
                                        'LOCKED (from sales shortage)',
                                        style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '₦${_formatAmount(e.amount)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}