// lib/features/fuel/presentation/widgets/entry_tabs/expense_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:temp_fuel_app/core/services/service_registry.dart';
import 'package:temp_fuel_app/core/models/expense_record.dart';

const panelBg = Color(0xFF0f172a);
const panelBorder = Color(0xFF1f2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);
const inputBorder = Color(0xFF334155);

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  ThousandsSeparatorInputFormatter({String locale = 'en_NG'})
      : _format = NumberFormat.decimalPattern(locale);

  final NumberFormat _format;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final formatted = _format.format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class ExpenseTab extends StatefulWidget {
  final VoidCallback onSubmitted;

  const ExpenseTab({super.key, required this.onSubmitted});

  @override
  State<ExpenseTab> createState() => _ExpenseTabState();
}

class _ExpenseTabState extends State<ExpenseTab> {
  final List<String> _categories = ['Maintenance', 'Salary', 'Generator Fuel', 'Misc'];
  String _selectedCategory = 'Maintenance';

  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController(); 

  ExpenseRecord? _editing;

  final money = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    Services.expense.addListener(_refresh);
    Services.expense.refreshToday();
  }

  @override
  void dispose() {
    Services.expense.removeListener(_refresh);
    amountCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  void _toast(String msg, {bool green = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: green ? Colors.green : Colors.red),
    );
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  InputDecoration _input(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: textSecondary),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: inputBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.orange),
          borderRadius: BorderRadius.circular(10),
        ),
      );

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0.0;

  void _resetForm() {
    amountCtrl.clear();
    noteCtrl.clear();
    _editing = null;
    setState(() {});
  }

  Future<void> _addCategoryDialog() async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: panelBg,
        title: const Text('New Category', style: TextStyle(color: textPrimary)),
        content: TextField(
          controller: ctrl,
          decoration: _input('Category name'),
          style: const TextStyle(color: textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    final v = (res ?? '').trim();
    if (v.isEmpty) return;

    setState(() {
      if (!_categories.contains(v)) _categories.add(v);
      _selectedCategory = v;
    });
  }

  Future<void> _recordOrUpdate() async {
    final amount = _num(amountCtrl);
    if (amount <= 0) {
      _toast('Enter a valid amount');
      return;
    }

    try {
      if (_editing == null) {
        await Services.expense.createDraftExpense(
          amount: amount,
          category: _selectedCategory,
          comment: noteCtrl.text.trim(),
        );
        _toast('Recorded (Draft).', green: true);
      } else {
        await Services.expense.updateDraftExpense(
          id: _editing!.id,
          amount: amount,
          category: _selectedCategory,
          comment: noteCtrl.text.trim(),
        );
        _toast('Updated.', green: true);
      }

      _resetForm();
      await Services.expense.refreshToday();
    } catch (e) {
      _toast('Error: $e');
    }
  }

  void _editExpense(ExpenseRecord e) {
    if (e.isLocked || e.isSubmitted) return;
    _editing = e;

    amountCtrl.text = NumberFormat.decimalPattern('en_NG').format(e.amount.round());
    noteCtrl.text = e.comment;
    _selectedCategory = e.category;

    setState(() {});
  }

  Future<void> _deleteExpense(ExpenseRecord e) async {
    if (e.isLocked || e.isSubmitted) return;

    try {
      await Services.expense.deleteDraftExpense(e.id);
      await Services.expense.refreshToday();
      _toast('Deleted.', green: true);
    } catch (err) {
      _toast('Error: $err');
    }
  }

  Future<void> _clearDrafts() async {
    try {
      await Services.expense.clearTodayDrafts();
      await Services.expense.refreshToday();
      _resetForm();
      _toast('Drafts cleared.', green: true);
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<void> _submitExpenses() async {
    try {
      final count = await Services.expense.submitTodayExpenses();

      if (count == 0) {
        _toast('No expenses to submit.');
        return;
      }

      await Services.expense.refreshToday();
      _resetForm();
      widget.onSubmitted();  // call to mark weekly summary

      _toast('Submitted $count expense(s). List cleared.', green: true);
    } catch (e) {
      _toast('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final drafts = Services.expense.todayDrafts; // use this for the list
    final allExpenses = drafts; // the list should only show drafts

    final total = Services.expense.todayExpenseTotal;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Form (unchanged)
          Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 46,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    dropdownColor: panelBg,
                    decoration: _input('Category'),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: textPrimary)))).toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v ?? _selectedCategory),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 46,
                width: 52,
                child: OutlinedButton(
                  onPressed: _addCategoryDialog,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: inputBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Icon(Icons.add, color: Colors.greenAccent),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 46,
                  child: TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      ThousandsSeparatorInputFormatter(locale: 'en_NG'),
                    ],
                    decoration: _input('Amount (₦)'),
                    style: const TextStyle(color: textPrimary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 6,
                child: SizedBox(
                  height: 72,
                  child: TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    decoration: _input('Note / Description'),
                    style: const TextStyle(color: textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 72,
                width: 150,
                child: ElevatedButton(
                  onPressed: _recordOrUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _editing == null ? 'Record\nExpense' : 'Update\nExpense',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Header - use allExpenses.length
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Expenses (${drafts.length})",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
              ),
              Text(
                'Total: ${money.format(total)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // List - use allExpenses
          Expanded(
            child: allExpenses.isEmpty
                ? const Center(
                    child: Text('No expenses recorded for today.', style: TextStyle(color: textSecondary)),
                  )
                : ListView.separated(
                    itemCount: allExpenses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final e = allExpenses[i];
                      final isEditable = !e.isLocked && !e.isSubmitted;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: e.isLocked ? Colors.redAccent : panelBorder,
                            width: e.isLocked ? 1.5 : 1,
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
                                      color: e.isLocked ? Colors.redAccent : textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (e.comment.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      e.comment,
                                      style: const TextStyle(color: textSecondary, fontSize: 12),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (e.isSubmitted && !e.isLocked)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Submitted',
                                        style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              money.format(e.amount),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.redAccent),
                            ),
                            const SizedBox(width: 10),
                            if (isEditable) ...[
                              IconButton(
                                onPressed: () => _editExpense(e),
                                icon: const Icon(Icons.edit, color: Colors.white70),
                              ),
                              IconButton(
                                onPressed: () => _deleteExpense(e),
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearDrafts,  // no disable
                  label: const Text('Clear Drafts'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: inputBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: allExpenses.isEmpty ? null : _submitExpenses,// Always ON
                  label: Text(
                    allExpenses.isEmpty ? 'Submit (0)' : 'Submit (${drafts.length})',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: drafts.isEmpty ? Colors.grey : Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}