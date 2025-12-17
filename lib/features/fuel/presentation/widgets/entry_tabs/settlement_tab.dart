// lib/features/fuel/presentation/widgets/entry_tabs/settlement_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/* ===================== COLORS ===================== */

const panelBg = Color(0xFF111827);
const panelBorder = Color(0xFF1f2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);
const inputBorder = Color(0xFF334155);

/* ===================== MODEL ===================== */

class DebtRecord {
  final String supplier;
  final String fuel;
  final String source;
  final double amount;
  final DateTime date;

  DebtRecord({
    required this.supplier,
    required this.fuel,
    required this.source,
    required this.amount,
    required this.date,
  });
}

/* ===================== WIDGET ===================== */

class SettlementTab extends StatefulWidget {
  final VoidCallback onSubmitted;
  const SettlementTab({super.key, required this.onSubmitted});

  @override
  State<SettlementTab> createState() => _SettlementTabState();
}

class _SettlementTabState extends State<SettlementTab> {
  final suppliers = ['Onyis Fuel', 'Val Oil'];
  final fuels = ['Petrol (PMS)', 'Diesel (AGO)', 'Gas (LPG)'];
  final sources = ['Sales', 'External', 'Sales + External'];

  String supplier = 'Onyis Fuel';
  String fuel = 'Gas (LPG)';
  String source = 'Sales';

  final salesCtrl = TextEditingController();
  final extCtrl = TextEditingController();

  int? selectedIndex;

  final money = NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 2,
  );

  /* ===================== MOCK DEBTS ===================== */
  final List<DebtRecord> debts = [
    DebtRecord(
      supplier: 'Onyis Fuel',
      fuel: 'Gas (LPG)',
      source: 'External',
      amount: 50000,
      date: DateTime.now().subtract(const Duration(days: 2)),
    ),
    DebtRecord(
      supplier: 'Val Oil',
      fuel: 'Gas (LPG)',
      source: 'Sales',
      amount: 500000,
      date: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  double get totalDebt =>
      debts.fold(0, (sum, d) => sum + d.amount);

  double get overPaid => 0; // placeholder for future logic

  void _undo() {
    salesCtrl.clear();
    extCtrl.clear();
    selectedIndex = null;
    setState(() {});
  }

  /* ===================== INPUT ===================== */

  InputDecoration _input(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: textSecondary),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: inputBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blue),
          borderRadius: BorderRadius.circular(8),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /* ===================== FORM ===================== */

          Row(
            children: [
              Expanded(
                child: _dropdown(
                  'Supplier',
                  supplier,
                  suppliers,
                  (v) => setState(() => supplier = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dropdown(
                  'Fuel',
                  fuel,
                  fuels,
                  (v) => setState(() => fuel = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dropdown(
                  'Source',
                  source,
                  sources,
                  (v) => setState(() => source = v!),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _field(
                  'Sales Amount (₦)',
                  salesCtrl,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  'External Amount (₦)',
                  extCtrl,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _undo,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: selectedIndex == null
                      ? null
                      : () {
                          widget.onSubmitted();
                          _undo();
                        },
                  icon: const Icon(Icons.payment),
                  label: const Text('Settle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          /* ===================== SUMMARY ===================== */

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryChip(
                'Outstanding',
                money.format(totalDebt),
                totalDebt > 0 ? Colors.red : Colors.green,
              ),
              _summaryChip(
                'Total Debt',
                money.format(totalDebt),
                Colors.orange,
              ),
              _summaryChip(
                'Overpaid',
                money.format(overPaid),
                Colors.green,
              ),
            ],
          ),

          const SizedBox(height: 16),

          /* ===================== DEBT LIST ===================== */

          Expanded(
            child: ListView.separated(
              itemCount: debts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final d = debts[i];

                return GestureDetector(
                  onTap: () => setState(() => selectedIndex = i),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selectedIndex == i
                          ? Colors.blue.withOpacity(0.15)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: panelBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Line 1
                        Text(
                          '${d.supplier} • ${d.fuel} • ${d.source}',
                          style: const TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Line 2
                        Text(
                          '${DateFormat('dd MMM yyyy').format(d.date)} • ${money.format(d.amount)}',
                          style: const TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Line 3
                        Text(
                          'DEBT ${money.format(d.amount)}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
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

  Widget _summaryChip(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

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
          decoration: _input(label),
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(color: textPrimary)),
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
