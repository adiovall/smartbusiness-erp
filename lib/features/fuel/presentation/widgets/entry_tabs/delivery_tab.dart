import 'package:flutter/material.dart';

/* ===================== COLORS ===================== */

const panelBg = Color(0xFF0f172a);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);
const inputBorder = Color(0xFF334155);

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
  final salesAmtCtrl = TextEditingController();
  final extAmtCtrl = TextEditingController();

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

  bool get showSplit => source == 'External+Sales';

  double get balance =>
      (double.tryParse(costCtrl.text) ?? 0) -
      (double.tryParse(paidCtrl.text) ?? 0);

  void _undo() {
    supplierCtrl.clear();
    litersCtrl.clear();
    costCtrl.clear();
    paidCtrl.clear();
    salesAmtCtrl.clear();
    extAmtCtrl.clear();
    setState(() {});
  }

  /* ===================== INPUT STYLE ===================== */

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: textSecondary),
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      isDense: true,
      constraints: const BoxConstraints(minHeight: 48), // 🔥 pixel fix
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
          /* ===================== DELIVERY ===================== */
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                // Supplier (Autocomplete) — height locked
                Autocomplete<String>(
                  optionsBuilder: (_) => filtered,
                  onSelected: (v) => supplierCtrl.text = v,
                  fieldViewBuilder: (_, controller, focusNode, __) =>
                      SizedBox(
                    height: 48,
                    child: TextField(
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
              ],
            ),
          ),

          const SizedBox(width: 30),

          /* ===================== PAYMENT ===================== */
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(child: _field('Amount Paid (₦)', paidCtrl)),
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

                if (showSplit) ...[
                  _field('Sales Amount (₦)', salesAmtCtrl),
                  _field('External Amount (₦)', extAmtCtrl),
                ],

                _readonlyBox(
                  'Balance',
                  balance.toStringAsFixed(0),
                  balance > 0 ? Colors.red : Colors.green,
                ),

                const SizedBox(height: 20),

                // Undo + Submit (pixel-safe)
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
                          icon: const Icon(Icons.local_shipping),
                          label: const Text('Submit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                        ),
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

  /* ===================== HELPERS ===================== */

  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: DropdownButtonFormField<String>(
          value: value,
          isDense: true,
          dropdownColor: panelBg,
          decoration: _input(label),
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: textPrimary),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
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
            onChanged: (_) => setState(() {}),
          ),
        ),
      );

  Widget _readonlyBox(String label, String value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: inputBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: textSecondary,
                ),
              ),
              Text(
                '₦$value',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
}
