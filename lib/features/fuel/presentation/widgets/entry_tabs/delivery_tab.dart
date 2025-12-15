// lib/features/fuel/presentation/widgets/entry_tabs/delivery_tab.dart

import 'package:flutter/material.dart';

/* ===================== COLORS ===================== */

const panelBg = Color(0xFF0f172a);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);
const inputBorder = Color(0xFF334155);

/* ===================== MODEL ===================== */

class DeliveryRecord {
  final String supplier;
  final String fuel;
  final double liters;
  final double cost;
  final double paid;
  final String source;

  DeliveryRecord({
    required this.supplier,
    required this.fuel,
    required this.liters,
    required this.cost,
    required this.paid,
    required this.source,
  });

  double get balance => cost - paid;
}

/* ===================== WIDGET ===================== */

class DeliveryTab extends StatefulWidget {
  final VoidCallback onSubmitted;
  const DeliveryTab({super.key, required this.onSubmitted});

  @override
  State<DeliveryTab> createState() => _DeliveryTabState();
}

class _DeliveryTabState extends State<DeliveryTab> {
  final knownSuppliers = [
    'Micheal',
    'Onyis Fuel',
    'NNPC Depot',
    'Val Oil',
    'Total Energies',
  ];

  final fuels = ['Petrol (PMS)', 'Diesel (AGO)', 'Kerosene (HHK)', 'Gas (LPG)'];
  final sources = ['External', 'Sales', 'External+Sales'];

  String fuel = 'Petrol (PMS)';
  String source = 'External';

  final supplierCtrl = TextEditingController();
  final litersCtrl = TextEditingController();
  final costCtrl = TextEditingController();
  final paidCtrl = TextEditingController();

  final List<DeliveryRecord> records = [];

  List<String> filtered = [];

  @override
  void initState() {
    super.initState();
    filtered = knownSuppliers;
    supplierCtrl.addListener(() {
      final q = supplierCtrl.text.toLowerCase();
      setState(() {
        filtered =
            knownSuppliers.where((s) => s.toLowerCase().contains(q)).toList();
      });
    });
  }

  double get totalLiters =>
      records.fold(0, (s, r) => s + r.liters);
  double get totalCost =>
      records.fold(0, (s, r) => s + r.cost);
  double get totalBalance =>
      records.fold(0, (s, r) => s + r.balance);

  void _undo() {
    supplierCtrl.clear();
    litersCtrl.clear();
    costCtrl.clear();
    paidCtrl.clear();
    setState(() {});
  }

  void _recordDelivery() {
    records.add(
      DeliveryRecord(
        supplier: supplierCtrl.text,
        fuel: fuel,
        liters: double.tryParse(litersCtrl.text) ?? 0,
        cost: double.tryParse(costCtrl.text) ?? 0,
        paid: double.tryParse(paidCtrl.text) ?? 0,
        source: source,
      ),
    );
    _undo();
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
        borderSide: const BorderSide(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /* ===================== ENTRY ===================== */
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery Entry',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  height: 48,
                  child: Autocomplete<String>(
                    optionsBuilder: (_) => filtered,
                    onSelected: (v) => supplierCtrl.text = v,
                    fieldViewBuilder:
                        (_, controller, focusNode, __) => TextField(
                      controller: supplierCtrl,
                      focusNode: focusNode,
                      decoration: _input('Supplier'),
                      style: const TextStyle(color: textPrimary),
                    ),
                  ),
                ),

                _dropdown('Fuel Type', fuel, fuels,
                    (v) => setState(() => fuel = v!)),
                _field('Liters Received', litersCtrl),
                _field('Total Cost (₦)', costCtrl),

                Row(
                  children: [
                    Expanded(child: _field('Amount Paid (₦)', paidCtrl)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: DropdownButtonFormField<String>(
                          value: source,
                          isDense: true,
                          isExpanded: true,
                          dropdownColor: panelBg,
                          decoration: _input('Source'),
                          items: sources
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e,
                                      style: const TextStyle(
                                          color: textPrimary)),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => source = v!),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

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
                        onPressed: supplierCtrl.text.isEmpty
                            ? null
                            : _recordDelivery,
                        icon: const Icon(Icons.add),
                        label: const Text('Record'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 30),

          /* ===================== SUMMARY ===================== */
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                if (records.isEmpty)
                  const Text(
                    'No deliveries recorded',
                    style: TextStyle(color: textSecondary),
                  ),

                ...records.asMap().entries.map(
                  (e) {
                    final i = e.key;
                    final r = e.value;
                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      child: ListTile(
                        title: Text(
                          '${r.supplier} • ${r.fuel}',
                          style: const TextStyle(color: textPrimary),
                        ),
                        subtitle: Text(
                          '${r.liters}L  |  ₦${r.cost.toStringAsFixed(0)}',
                          style:
                              const TextStyle(color: textSecondary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red),
                              onPressed: () =>
                                  setState(() => records.removeAt(i)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                _summaryRow('Total Liters', '${totalLiters.toStringAsFixed(0)} L'),
                _summaryRow('Total Cost', '₦${totalCost.toStringAsFixed(0)}'),
                _summaryRow(
                  'Outstanding',
                  '₦${totalBalance.toStringAsFixed(0)}',
                  color: totalBalance > 0
                      ? Colors.red
                      : Colors.green,
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: records.isEmpty
                        ? null
                        : () {
                            widget.onSubmitted();
                            records.clear();
                            setState(() {});
                          },
                    icon: const Icon(Icons.send),
                    label: const Text('Submit All Deliveries'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* ===================== HELPERS ===================== */

  Widget _dropdown(String label, String value, List<String> items,
          Function(String?) onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
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
                    child: Text(e,
                        style:
                            const TextStyle(color: textPrimary)),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      );

  Widget _field(String label, TextEditingController ctrl) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          height: 48,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: _input(label),
            style: const TextStyle(color: textPrimary),
          ),
        ),
      );

  Widget _summaryRow(String label, String value,
          {Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    const TextStyle(color: textSecondary)),
            Text(value,
                style: TextStyle(
                  color: color ?? textPrimary,
                  fontWeight: FontWeight.bold,
                )),
          ],
        ),
      );
}
