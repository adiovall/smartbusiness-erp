import 'package:flutter/material.dart';

/* ===================== COLORS ===================== */

const panelBg = Color(0xFF0f172a);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);
const inputBorder = Color(0xFF334155);

class SaleTab extends StatefulWidget {
  final Function(double amount) onSaleRecorded;
  const SaleTab({super.key, required this.onSaleRecorded});

  @override
  State<SaleTab> createState() => _SaleTabState();
}

class _SaleTabState extends State<SaleTab> {
  final pumps = List.generate(12, (i) => 'Pump ${i + 1}');
  final fuels = ['Petrol (PMS)', 'Diesel (AGO)', 'Kerosene (HHK)', 'Gas (LPG)'];

  String pump = 'Pump 1', fuel = 'Petrol (PMS)';

  final o = TextEditingController();
  final c = TextEditingController();
  final p = TextEditingController(text: '865');
  final cash = TextEditingController();
  final pos = TextEditingController();

  double get liters =>
      (double.tryParse(c.text) ?? 0) - (double.tryParse(o.text) ?? 0);
  double get total => liters * (double.tryParse(p.text) ?? 0);
  double get received =>
      (double.tryParse(cash.text) ?? 0) + (double.tryParse(pos.text) ?? 0);

  void _undo() {
    o.clear();
    c.clear();
    cash.clear();
    pos.clear();
    setState(() {});
  }

  InputDecoration _input(String label, {String? suffix}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffix,
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
        borderSide: const BorderSide(color: Colors.green),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = liters > 0 && received >= total;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /* RECORD */
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Record',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textPrimary)),
              const SizedBox(height: 10),

              _dropdown('Pump Number', pump, pumps,
                  (v) => setState(() => pump = v!)),
              _dropdown('Fuel Type', fuel, fuels,
                  (v) => setState(() => fuel = v!)),
              _field('Opening Reading', o),
              _field('Closing Reading', c),
              _field('Unit Price', p, suffix: '₦'),
              _readonlyBox('Total Amount', total.toStringAsFixed(0),
                  Colors.green),
            ]),
          ),

          const SizedBox(width: 30),

          /* PAYMENT */
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Payment',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textPrimary)),
              const SizedBox(height: 10),

              _field('Total Cash', cash, suffix: '₦'),
              _field('Total POS', pos, suffix: '₦'),

              _readonlyBox(
                'Total Money',
                received.toStringAsFixed(0),
                received >= total ? Colors.green : Colors.red,
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _undo,
                      icon: const Icon(Icons.undo),
                      label: const Text('Undo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textSecondary,
                        side: const BorderSide(color: inputBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canSubmit
                          ? () {
                              widget.onSaleRecorded(received);
                              _undo();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Sale recorded'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Submit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _dropdown(String label, String v, List<String> items,
          Function(String?) f) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: DropdownButtonFormField<String>(
          value: v,
          dropdownColor: panelBg,
          decoration: _input(label),
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e,
                        style: const TextStyle(color: textPrimary)),
                  ))
              .toList(),
          onChanged: f,
        ),
      );

  Widget _field(String label, TextEditingController ctrl,
          {String? suffix}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: _input(label, suffix: suffix),
          style: const TextStyle(color: textPrimary),
          onChanged: (_) => setState(() {}),
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
              Text(label,
                  style:
                      const TextStyle(color: textSecondary, fontSize: 14)),
              Text('₦$value',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
        ),
      );
}
