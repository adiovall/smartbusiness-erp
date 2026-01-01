// lib/features/fuel/presentation/widgets/entry_tabs/delivery_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/../core/services/service_registry.dart'; // ← ADD THIS
import '/../core/models/tank_state.dart';

/* ===================== COLORS ===================== */
const panelBg = Color(0xFF111827);
const cardBg = Color(0xFF1F2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);
const inputBorder = Color(0xFF374151);

/* ===================== MODEL ===================== */
class DeliveryRecord {
  final String supplier;
  final String fuel;
  final double liters;
  final double cost;
  final double paid;
  final double salesPaid;
  final double externalPaid;

  DeliveryRecord({
    required this.supplier,
    required this.fuel,
    required this.liters,
    required this.cost,
    required this.paid,
    this.salesPaid = 0,
    this.externalPaid = 0,
  });

  double get debt => paid < cost ? cost - paid : 0;

  Map<String, dynamic> toJson() => {
        'supplier': supplier,
        'fuel': fuel,
        'liters': liters,
        'cost': cost,
        'paid': paid,
        'salesPaid': salesPaid,
        'externalPaid': externalPaid,
        'date': DateTime.now().toIso8601String(),
      };
}

/* ===================== WIDGET ===================== */
class DeliveryTab extends StatefulWidget {
  final VoidCallback onSubmitted;
  final Function(double amount) onDeliveryRecorded; // ← NEW PARAMETER

  const DeliveryTab({
    super.key,
    required this.onSubmitted,
    required this.onDeliveryRecorded, // ← REQUIRED
  });

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

  final fuels = ['PMS', 'AGO', 'DPK', 'Gas']; // ← Match Tank fuelType exactly!
  final sources = ['External', 'Sales', 'External+Sales'];

  String selectedFuel = 'PMS';
  String source = 'External';

  final supplierCtrl = TextEditingController();
  final litersCtrl = TextEditingController();
  final costCtrl = TextEditingController();
  final paidCtrl = TextEditingController();
  final salesCtrl = TextEditingController();
  final externalCtrl = TextEditingController();

  final List<DeliveryRecord> records = [];

  final money = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  bool get showSplit => source == 'External+Sales';

  double get amountPaid {
    if (showSplit) {
      return (double.tryParse(salesCtrl.text) ?? 0) + (double.tryParse(externalCtrl.text) ?? 0);
    }
    return double.tryParse(paidCtrl.text) ?? 0;
  }

  /* ===================== TOTALS ===================== */
  double get totalLiters => records.fold(0, (sum, r) => sum + r.liters);
  double get totalCost => records.fold(0, (sum, r) => sum + r.cost);
  double get totalPaid => records.fold(0, (sum, r) => sum + r.paid);
  double get outstanding => totalCost - totalPaid;

  /* ===================== ACTIONS ===================== */
  void _record() async {
    final supplier = supplierCtrl.text.trim();
    final liters = double.tryParse(litersCtrl.text) ?? 0;
    final cost = double.tryParse(costCtrl.text) ?? 0;

    if (supplier.isEmpty || liters <= 0 || cost <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields correctly')),
      );
      return;
    }

    // Check tank capacity
    final tank = Services.tank.getTank(selectedFuel);
    if (tank != null) {
      final newLevel = tank.currentLevel + liters;
      if (newLevel > tank.capacity) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: panelBg,
            title: Text('Tank Capacity Warning', style: TextStyle(color: textPrimary)),
            content: Text(
              'Adding ${liters.toInt()}L will exceed ${selectedFuel} tank capacity '
              '(${tank.capacity.toInt()}L). Current: ${tank.currentLevel.toInt()}L\n\n'
              'Proceed anyway?',
              style: TextStyle(color: textSecondary),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Proceed')),
            ],
          ),
        );

        if (proceed != true) return;
      }

      // Add to tank
      await Services.tank.addFuel(selectedFuel, liters);
    }

    // Create record
    final record = DeliveryRecord(
      supplier: supplier,
      fuel: selectedFuel,
      liters: liters,
      cost: cost,
      paid: amountPaid,
      salesPaid: showSplit ? (double.tryParse(salesCtrl.text) ?? 0) : 0,
      externalPaid: showSplit ? (double.tryParse(externalCtrl.text) ?? 0) : amountPaid,
    );

    setState(() => records.add(record));

    // Create debt if needed
    if (record.debt > 0) {
      await Services.debt.createDebt(
        supplier: supplier,
        fuelType: selectedFuel,
        amount: record.debt,
      );
    }

    widget.onDeliveryRecorded(totalCost); // Update main screen

    _clear();
    widget.onSubmitted(); // Mark as draft immediately
  }

  void _clear() {
    supplierCtrl.clear();
    litersCtrl.clear();
    costCtrl.clear();
    paidCtrl.clear();
    salesCtrl.clear();
    externalCtrl.clear();
  }

  void _submit() {
    widget.onSubmitted();
    setState(() => records.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Delivery submitted successfully'), backgroundColor: Colors.green),
    );
  }

  /* ===================== UI ===================== */
  InputDecoration _input(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: textSecondary),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: inputBorder), borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.orange), borderRadius: BorderRadius.circular(8)),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /* ENTRY FORM */
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Delivery Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
              const SizedBox(height: 10),

              _autocomplete('Supplier', supplierCtrl),
              const SizedBox(height: 8),
              _dropdown('Fuel Type', selectedFuel, fuels, (v) => setState(() => selectedFuel = v!)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _field('Liters', litersCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _field('Total Cost (₦)', costCtrl)),
              ]),
              const SizedBox(height: 14),
              const Text('Payment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: showSplit ? _field('Sales (₦)', salesCtrl) : _field('Amount Paid (₦)', paidCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _dropdown('Source', source, sources, (v) => setState(() => source = v!))),
              ]),
              if (showSplit) ...[const SizedBox(height: 8), _field('External (₦)', externalCtrl)],
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _record,
                  icon: const Icon(Icons.local_shipping),
                  label: const Text('Record Delivery'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
              ),
            ]),
          ),

          const SizedBox(width: 24),

          /* SUMMARY */
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Today\'s Deliveries', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
              const SizedBox(height: 12),
              _summaryRow('Total Liters', '${totalLiters.toInt()} L'),
              _summaryRow('Total Cost', money.format(totalCost)),
              _summaryRow('Total Paid', money.format(totalPaid), color: Colors.green),
              _summaryRow('Outstanding Debt', money.format(outstanding), color: outstanding > 0 ? Colors.red : Colors.green),
              const SizedBox(height: 16),
              Expanded(
                child: records.isEmpty
                    ? const Center(child: Text('No deliveries recorded today', style: TextStyle(color: textSecondary)))
                    : ListView.builder(
                        itemCount: records.length,
                        itemBuilder: (_, i) {
                          final r = records[i];
                          return Card(
                            color: cardBg,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text('${r.supplier} • ${r.fuel}', style: const TextStyle(color: textPrimary)),
                              subtitle: Text('${r.liters.toInt()}L • ${money.format(r.cost)}', style: const TextStyle(color: textSecondary)),
                              trailing: Text(
                                r.debt > 0 ? 'DEBT ${money.format(r.debt)}' : 'PAID',
                                style: TextStyle(color: r.debt > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: _clear, icon: const Icon(Icons.undo), label: const Text('Clear'))),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: records.isNotEmpty ? _submit : null,
                    icon: const Icon(Icons.send),
                    label: const Text('Submit Day'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: textSecondary)),
          Text(value, style: TextStyle(color: color ?? textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _autocomplete(String label, TextEditingController c) => Autocomplete<String>(
        optionsBuilder: (_) => suppliers.where((s) => s.toLowerCase().contains(c.text.toLowerCase())),
        onSelected: (v) => c.text = v,
        fieldViewBuilder: (_, ctrl, focus, __) => TextField(controller: ctrl, focusNode: focus, decoration: _input(label)),
      );

  Widget _dropdown(String label, String v, List<String> items, Function(String?) f) => DropdownButtonFormField<String>(
        value: v,
        decoration: _input(label),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: f,
      );

  Widget _field(String label, TextEditingController c) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: _input(label),
      );
}