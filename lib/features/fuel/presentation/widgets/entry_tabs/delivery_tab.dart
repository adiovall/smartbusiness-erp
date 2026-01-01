// lib/features/fuel/presentation/widgets/entry_tabs/delivery_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/../core/services/service_registry.dart';
import '/../core/models/delivery_record.dart' as core;

/* ===================== COLORS ===================== */
const panelBg = Color(0xFF111827);
const cardBg = Color(0xFF1F2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);
const inputBorder = Color(0xFF374151);

class DeliveryTab extends StatefulWidget {
  final VoidCallback onSubmitted;
  final Function(double amount) onDeliveryRecorded;

  const DeliveryTab({
    super.key,
    required this.onSubmitted,
    required this.onDeliveryRecorded,
  });

  @override
  State<DeliveryTab> createState() => _DeliveryTabState();
}

class _DeliveryTabState extends State<DeliveryTab> {
  // seed names (optional)
  final List<String> _seedSuppliers = const [
    'Micheal',
    'Onyis Fuel',
    'NNPC Depot',
    'Val Oil',
    'Total Energies',
  ];

  final fuels = const ['PMS', 'AGO', 'DPK', 'Gas']; // must match Tank fuelType
  final sources = const ['External', 'Sales', 'External+Sales'];

  String selectedFuel = 'PMS';
  String source = 'External';

  final supplierCtrl = TextEditingController();
  final litersCtrl = TextEditingController();
  final costCtrl = TextEditingController();
  final paidCtrl = TextEditingController();
  final salesCtrl = TextEditingController();
  final externalCtrl = TextEditingController();

  final money = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
  final commas = NumberFormat.decimalPattern('en_NG');

  // suppliers that autocomplete uses (loaded from DB + seed)
  List<String> supplierSuggestions = [];
  bool _loadingSuppliers = true;

  bool get showSplit => source == 'External+Sales';

  double _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;

  double get amountPaid {
    if (showSplit) return _num(salesCtrl) + _num(externalCtrl);
    return _num(paidCtrl);
  }

  List<core.DeliveryRecord> get records => Services.delivery.todayDeliveries;

  double get totalLiters => records.fold(0.0, (sum, r) => sum + r.liters);
  double get totalCost => records.fold(0.0, (sum, r) => sum + r.totalCost);
  double get totalPaid => records.fold(0.0, (sum, r) => sum + r.amountPaid);
  double get outstanding => totalCost - totalPaid;

  @override
  void initState() {
    super.initState();
    _loadSupplierSuggestions();
  }

  Future<void> _loadSupplierSuggestions() async {
    setState(() => _loadingSuppliers = true);

    final set = <String>{..._seedSuppliers};

    // ✅ pull from DB: deliveries + settlements
    try {
      final dbNames = await Services.deliveryRepo.fetchAllSuppliersDistinct();
      for (final n in dbNames) {
        final name = n.trim();
        if (name.isNotEmpty) set.add(name);
      }
    } catch (_) {}

    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (!mounted) return;
    setState(() {
      supplierSuggestions = list;
      _loadingSuppliers = false;
    });
  }

  /* ===================== ACTIONS ===================== */
  Future<void> _record() async {
    final supplier = supplierCtrl.text.trim();
    final liters = _num(litersCtrl);
    final cost = _num(costCtrl);

    if (supplier.isEmpty || liters <= 0 || cost <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields correctly')),
      );
      return;
    }

    // capacity warning (UI-only)
    final tank = Services.tank.getTank(selectedFuel);
    if (tank != null) {
      final newLevel = tank.currentLevel + liters;
      if (newLevel > tank.capacity) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: panelBg,
            title: const Text('Tank Capacity Warning', style: TextStyle(color: textPrimary)),
            content: Text(
              'Adding ${commas.format(liters.toInt())}L will exceed $selectedFuel tank capacity '
              '(${commas.format(tank.capacity.toInt())}L).\n'
              'Current: ${commas.format(tank.currentLevel.toInt())}L\n\n'
              'Proceed anyway?',
              style: const TextStyle(color: textSecondary),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Proceed')),
            ],
          ),
        );

        if (proceed != true) return;
      }
    }

    try {
      // ✅ use your core service (saves to DB + creates debt properly)
      await Services.delivery.recordDelivery(
        supplier: supplier,
        fuelType: selectedFuel,
        liters: liters,
        totalCost: cost,
        amountPaid: amountPaid,
        source: source,
      );

      // update UI + top card
      widget.onDeliveryRecorded(Services.delivery.todayTotalCost);

      // add new supplier into suggestion list immediately
      if (!supplierSuggestions.any((s) => s.toLowerCase() == supplier.toLowerCase())) {
        setState(() {
          supplierSuggestions = [...supplierSuggestions, supplier]
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        });
      }

      _clear();
      widget.onSubmitted(); // mark as draft immediately

      if (mounted) setState(() {}); // refresh list

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
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
    _clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Delivery submitted successfully'),
        backgroundColor: Colors.green,
      ),
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
          /* ENTRY FORM */
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery Entry',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                const SizedBox(height: 10),

                _supplierAutocomplete('Supplier', supplierCtrl),
                const SizedBox(height: 8),

                _dropdown('Fuel Type', selectedFuel, fuels, (v) => setState(() => selectedFuel = v!)),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(child: _field('Liters', litersCtrl)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('Total Cost (₦)', costCtrl)),
                  ],
                ),

                const SizedBox(height: 14),
                const Text(
                  'Payment',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
                ),
                const SizedBox(height: 8),

                // responsive payment row (prevents overflow)
                LayoutBuilder(
                  builder: (context, c) {
                    final tight = c.maxWidth < 520;

                    final paidField = showSplit
                        ? _field('Sales (₦)', salesCtrl)
                        : _field('Amount Paid (₦)', paidCtrl);

                    final sourceDrop = _dropdown('Source', source, sources, (v) => setState(() => source = v!));

                    if (!tight) {
                      return Row(
                        children: [
                          Expanded(flex: 3, child: paidField),
                          const SizedBox(width: 8),
                          Expanded(flex: 2, child: sourceDrop),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        paidField,
                        const SizedBox(height: 8),
                        sourceDrop,
                      ],
                    );
                  },
                ),

                if (showSplit) ...[
                  const SizedBox(height: 8),
                  _field('External (₦)', externalCtrl),
                ],

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
              ],
            ),
          ),

          const SizedBox(width: 24),

          /* SUMMARY */
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today\'s Deliveries',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                const SizedBox(height: 12),

                _summaryRow('Total Liters', '${commas.format(totalLiters.toInt())} L'),
                _summaryRow('Total Cost', money.format(totalCost)),
                _summaryRow('Total Paid', money.format(totalPaid), color: Colors.green),
                _summaryRow(
                  'Outstanding Debt',
                  money.format(outstanding),
                  color: outstanding > 0 ? Colors.red : Colors.green,
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: records.isEmpty
                      ? const Center(
                          child: Text('No deliveries recorded today', style: TextStyle(color: textSecondary)),
                        )
                      : ListView.builder(
                          itemCount: records.length,
                          itemBuilder: (_, i) {
                            final r = records[i];
                            return Card(
                              color: cardBg,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                title: Text('${r.supplier} • ${r.fuelType}', style: const TextStyle(color: textPrimary)),
                                subtitle: Text(
                                  '${commas.format(r.liters.toInt())}L • ${money.format(r.totalCost)}',
                                  style: const TextStyle(color: textSecondary),
                                ),
                                trailing: Text(
                                  r.debt > 0 ? 'DEBT ${money.format(r.debt)}' : (r.credit > 0 ? 'CREDIT ${money.format(r.credit)}' : 'OK'),
                                  style: TextStyle(
                                    color: r.debt > 0 ? Colors.red : (r.credit > 0 ? Colors.cyan : Colors.green),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
                        onPressed: _clear,
                        icon: const Icon(Icons.undo),
                        label: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: records.isNotEmpty ? _submit : null,
                        label: const Text('Submit Day'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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

  /// ✅ Autocomplete: does not show all names until user types
  Widget _supplierAutocomplete(String label, TextEditingController c) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty(); // ✅ key behavior
        return supplierSuggestions
            .where((s) => s.toLowerCase().startsWith(q))
            .take(12);
      },
      onSelected: (v) => c.text = v,
      fieldViewBuilder: (_, ctrl, focus, __) {
        // keep your controller reference
        if (supplierCtrl != ctrl) supplierCtrl.value = ctrl.value;

        return TextField(
          controller: ctrl,
          focusNode: focus,
          decoration: _input(label).copyWith(
            suffixIcon: _loadingSuppliers
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : const Icon(Icons.search, color: Colors.white54),
          ),
          style: const TextStyle(color: textPrimary),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: const Color(0xFF0b1220),
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 420),
              child: ListView.builder(
                padding: const EdgeInsets.all(6),
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final opt = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    title: Text(opt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: textPrimary)),
                    onTap: () => onSelected(opt),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dropdown(String label, String v, List<String> items, Function(String?) f) {
    return DropdownButtonFormField<String>(
      value: v,
      isDense: true,
      isExpanded: true,
      dropdownColor: panelBg,
      decoration: _input(label),
      items: items
          .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: f,
    );
  }

  Widget _field(String label, TextEditingController c) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: _input(label),
        style: const TextStyle(color: textPrimary),
      );

  @override
  void dispose() {
    supplierCtrl.dispose();
    litersCtrl.dispose();
    costCtrl.dispose();
    paidCtrl.dispose();
    salesCtrl.dispose();
    externalCtrl.dispose();
    super.dispose();
  }
}
