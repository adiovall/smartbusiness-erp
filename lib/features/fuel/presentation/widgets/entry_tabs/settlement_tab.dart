import 'package:flutter/material.dart';

/* ===================== COLORS ===================== */

const panelBg = Color(0xFF0f172a);
const panelBorder = Color(0xFF1f2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);
const inputBorder = Color(0xFF334155);

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

  // 🔹 MOCK DEBTS (replace later with DB)
  final List<Map<String, dynamic>> debts = [
    {'supplier': 'Onyis Fuel', 'fuel': 'Gas (LPG)', 'amount': 50000.0},
    {'supplier': 'Val Oil', 'fuel': 'Gas (LPG)', 'amount': 500000.0},
  ];

  double get totalOutstanding =>
      debts.fold(0, (sum, d) => sum + d['amount']);

  void _undo() {
    salesCtrl.clear();
    extCtrl.clear();
    setState(() {});
  }

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
        borderSide: const BorderSide(color: Colors.blue),
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
          /* ===================== SETTLEMENT FORM ===================== */
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
              const SizedBox(width: 12),
              Expanded(
                child: _dropdown(
                  'Fuel Type',
                  fuel,
                  fuels,
                  (v) => setState(() => fuel = v!),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _dropdown(
            'Source',
            source,
            sources,
            (v) => setState(() => source = v!),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _field(
                  'Sales Amount (₦)',
                  salesCtrl,
                  enabled: source != 'External',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  'External Amount (₦)',
                  extCtrl,
                  enabled: source != 'Sales',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

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
                    onPressed: () {
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
              ),
            ],
          ),

          const SizedBox(height: 30),

          /* ===================== OUTSTANDING DEBTS ===================== */
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Outstanding Supplier Debts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              Text(
                'Total: ₦${totalOutstanding.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Expanded(
            child: ListView.separated(
              itemCount: debts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final d = debts[i];
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d['supplier'],
                              style: const TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              d['fuel'],
                              style: const TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₦${d['amount'].toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
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

  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool enabled = true,
  }) =>
      SizedBox(
        height: 48,
        child: TextField(
          controller: ctrl,
          enabled: enabled,
          keyboardType: TextInputType.number,
          decoration: _input(label),
          style: const TextStyle(color: textPrimary),
        ),
      );
}
