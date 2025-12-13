import 'package:flutter/material.dart';

/* ===================== COLORS ===================== */

const panelBg = Color(0xFF0f172a);
const panelBorder = Color(0xFF1f2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);
const inputBorder = Color(0xFF334155);

class ExpenseTab extends StatefulWidget {
  final VoidCallback onSubmitted;
  const ExpenseTab({super.key, required this.onSubmitted});

  @override
  State<ExpenseTab> createState() => _ExpenseTabState();
}

class _ExpenseTabState extends State<ExpenseTab> {
  final categories = ['Maintenance', 'Salary', 'Generator Fuel', 'Misc'];
  String category = 'Maintenance';

  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  final List<Map<String, String>> expenses = [];
  int? editingIndex;

  void _undo() {
    amountCtrl.clear();
    noteCtrl.clear();
    editingIndex = null;
    setState(() {});
  }

  void _record() {
    if (amountCtrl.text.isEmpty) return;

    final data = {
      'category': category,
      'amount': amountCtrl.text,
      'note': noteCtrl.text,
    };

    setState(() {
      if (editingIndex != null) {
        expenses[editingIndex!] = data;
        editingIndex = null;
      } else {
        expenses.insert(0, data);
      }
    });

    widget.onSubmitted();
    _undo();
  }

  void _edit(int index) {
    final e = expenses[index];
    setState(() {
      category = e['category']!;
      amountCtrl.text = e['amount']!;
      noteCtrl.text = e['note']!;
      editingIndex = index;
    });
  }

  void _delete(int index) {
    setState(() => expenses.removeAt(index));
  }

  /* ===================== INPUT STYLE ===================== */

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: textSecondary),
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /* ===================== TOP ROW ===================== */
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _dropdown(
                  'Category',
                  category,
                  categories,
                  (v) => setState(() => category = v!),
                ),
              ),
              const SizedBox(width: 10),

              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textSecondary,
                    side: const BorderSide(color: inputBorder),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                flex: 2,
                child: _field('Amount (₦)', amountCtrl),
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

          /* ===================== ACTIONS ===================== */
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _undo,
                    icon: const Icon(Icons.undo),
                    label: const Text('Undo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textSecondary,
                      side: const BorderSide(color: inputBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _record,
                    icon: const Icon(Icons.save),
                    label: Text(editingIndex != null ? 'Update' : 'Record'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          /* ===================== RECORDED EXPENSES ===================== */
          const Text(
            "Today's Expenses",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: expenses.isEmpty
                ? Center(
                    child: Text(
                      'No expenses recorded for today.',
                      style: TextStyle(color: textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: expenses.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final e = expenses[i];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: panelBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e['category']!,
                                    style: const TextStyle(
                                      color: textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (e['note']!.isNotEmpty)
                                    Text(
                                      e['note']!,
                                      style: const TextStyle(
                                        color: textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '₦${e['amount']}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              color: textSecondary,
                              onPressed: () => _edit(i),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              color: Colors.redAccent,
                              onPressed: () => _delete(i),
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

  /* ===================== HELPERS ===================== */

  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) =>
      SizedBox(
        height: 48,
        child: DropdownButtonFormField<String>(
          value: value,
          isDense: true,
          isExpanded: true,
          dropdownColor: panelBg,
          decoration: _input(label),
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e,
                    style: const TextStyle(color: textPrimary),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      );

  Widget _field(String label, TextEditingController ctrl) => SizedBox(
        height: 48,
        child: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: _input(label),
          style: const TextStyle(color: textPrimary),
        ),
      );
}
