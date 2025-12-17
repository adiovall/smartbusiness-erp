// lib/features/fuel/presentation/widgets/entry_tabs/delivery_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/* ===================== COLORS ===================== */

const panelBg = Color(0xFF111827); // lighter than before
const cardBg = Color(0xFF1F2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);
const inputBorder = Color(0xFF374151);

/* ===================== MODEL ===================== */

class DeliveryRecord {
  String supplier;
  String fuel;
  double liters;
  double cost;
  double paid;

  DeliveryRecord({
    required this.supplier,
    required this.fuel,
    required this.liters,
    required this.cost,
    required this.paid,
  });

  double get debt => paid < cost ? cost - paid : 0;
}

/* ===================== WIDGET ===================== */

class DeliveryTab extends StatefulWidget {
  final VoidCallback onSubmitted;
  const DeliveryTab({super.key, required this.onSubmitted});

  @override
  State<DeliveryTab> createState() => _DeliveryTabState();
}

class _DeliveryTabState extends State<DeliveryTab> {
  final suppliers = [
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
  final salesCtrl = TextEditingController();
  final externalCtrl = TextEditingController();

  final List<DeliveryRecord> records = [];

  final money = NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 2,
  );

  bool get showSplit => source == 'External+Sales';

  double get amountPaid {
    if (showSplit) {
      return (double.tryParse(salesCtrl.text) ?? 0) +
          (double.tryParse(externalCtrl.text) ?? 0);
    }
    return double.tryParse(paidCtrl.text) ?? 0;
  }

  /* ===================== TOTALS ===================== */

  double get totalLiters =>
      records.fold(0, (sum, r) => sum + r.liters);

  double get totalCost =>
      records.fold(0, (sum, r) => sum + r.cost);

  double get outstanding =>
      records.fold(0, (sum, r) => sum + r.debt);

  /* ===================== ACTIONS ===================== */

  void _record() {
    if (supplierCtrl.text.isEmpty) return;

    records.add(
      DeliveryRecord(
        supplier: supplierCtrl.text,
        fuel: fuel,
        liters: double.tryParse(litersCtrl.text) ?? 0,
        cost: double.tryParse(costCtrl.text) ?? 0,
        paid: amountPaid,
      ),
    );
    _clear();
    setState(() {});
  }

  void _clear() {
    supplierCtrl.clear();
    litersCtrl.clear();
    costCtrl.clear();
    paidCtrl.clear();
    salesCtrl.clear();
    externalCtrl.clear();
  }

  /* ===================== UI ===================== */

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
          borderSide: const BorderSide(color: Colors.orange),
          borderRadius: BorderRadius.circular(8),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /* ===================== ENTRY ===================== */
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Delivery Entry',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textPrimary)),
              const SizedBox(height: 10),

              // Supplier + Fuel
              Row(children: [
                Expanded(child: _autocomplete('Supplier', supplierCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _dropdown('Fuel Type', fuel, fuels,
                    (v) => setState(() => fuel = v!))),
              ]),

              // Liters + Cost
              Row(children: [
                Expanded(child: _field('Liters', litersCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _field('Total Cost (₦)', costCtrl)),
              ]),

              const SizedBox(height: 14),
              const Text('Payment',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textPrimary)),
              const SizedBox(height: 8),

              Row(children: [
                Expanded(
                    child: showSplit
                        ? _field('Sales (₦)', salesCtrl)
                        : _field('Amount Paid (₦)', paidCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _dropdown('Source', source, sources,
                    (v) => setState(() => source = v!))),
              ]),

              if (showSplit)
                _field('External (₦)', externalCtrl),

              const SizedBox(height: 14),

              SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _record,
                  icon: const Icon(Icons.add),
                  label: const Text('Record'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange),
                ),
              ),
            ]),
          ),

          const SizedBox(width: 24),

          /* ===================== SUMMARY ===================== */
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Delivery Summary',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textPrimary)),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Liters',
                      style: const TextStyle(color: textSecondary)),
                  Text('${totalLiters.toInt()} L',
                      style: const TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold)),
                  Text(money.format(totalCost),
                      style: const TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold)),
                ],
              ),

              const SizedBox(height: 6),
              Text(
                  outstanding > 0
                      ? 'Outstanding: ${money.format(outstanding)}'
                      : 'No Outstanding',
                  style: TextStyle(
                    color: outstanding > 0 ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              const SizedBox(height: 12),

              Expanded(
                child: records.isEmpty
                    ? const Center(
                        child: Text('No delivery recorded',
                            style: TextStyle(color: textSecondary)))
                    : ListView.builder(
                        itemCount: records.length,
                        itemBuilder: (_, i) {
                        final r = records[i];

                        return Card(
                          color: cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // LEFT DETAILS
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Line 1: Supplier • Fuel
                                      Text(
                                        '${r.supplier} • ${r.fuel}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      // Line 2: Liters • Cost
                                      Text(
                                        '${r.liters.toStringAsFixed(0)} L • ${money.format(r.cost)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      // Line 3: Status
                                      Text(
                                        r.debt > 0
                                            ? 'DEBT ${money.format(r.debt)}'
                                            : 'PAID',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: r.debt > 0 ? Colors.red : Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // RIGHT ACTIONS
                                Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      color: textSecondary,
                                      tooltip: 'Edit',
                                      onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Edit ${r.supplier}'),
                                          backgroundColor: Colors.blueGrey,
                                        ),
                                      );
                                    },

                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 18),
                                      color: Colors.redAccent,
                                      tooltip: 'Delete',
                                      onPressed: () {
                                        records.removeAt(i);
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );

                        },
                      ),
              ),

              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: _clear,
                        icon: const Icon(Icons.undo),
                        label: const Text('Undo'))),
                const SizedBox(width: 12),
                Expanded(
                    child: ElevatedButton.icon(
                        onPressed: () {
                          widget.onSubmitted();
                          records.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Submit'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange))),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  /* ===================== HELPERS ===================== */

  Widget _autocomplete(String label, TextEditingController c) =>
      SizedBox(
        height: 48,
        child: Autocomplete<String>(
          optionsBuilder: (_) => suppliers,
          onSelected: (v) => c.text = v,
          fieldViewBuilder: (_, ctrl, focus, __) =>
              TextField(controller: c, focusNode: focus, decoration: _input(label)),
        ),
      );

  Widget _dropdown(
          String label, String v, List<String> items, Function(String?) f) =>
      SizedBox(
        height: 48,
        child: DropdownButtonFormField<String>(
          value: v,
          isExpanded: true,
          decoration: _input(label),
          items:
              items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: f,
        ),
      );

  Widget _field(String label, TextEditingController c) =>
      SizedBox(
        height: 48,
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: _input(label),
        ),
      );
}
