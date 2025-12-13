// lib/features/fuel/presentation/widgets/entry_tabs/sale_tab.dart
import 'package:flutter/material.dart';

class SaleTab extends StatefulWidget {
  final Function(double amount) onSaleRecorded;
  const SaleTab({super.key, required this.onSaleRecorded});
  @override State<SaleTab> createState() => _SaleTabState();
}

class _SaleTabState extends State<SaleTab> {
  final pumps = List.generate(12, (i) => 'Pump ${i + 1}');
  final fuels = ['Petrol (PMS)', 'Diesel (AGO)', 'Kerosene (HHK)', 'Gas (LPG)'];
  String pump = 'Pump 1', fuel = 'Petrol (PMS)';
  final o = TextEditingController(), c = TextEditingController(), p = TextEditingController(text: '865');
  final cash = TextEditingController(), pos = TextEditingController();

  double get liters => (double.tryParse(c.text) ?? 0) - (double.tryParse(o.text) ?? 0);
  double get total => liters * (double.tryParse(p.text) ?? 0);
  double get received => (double.tryParse(cash.text) ?? 0) + (double.tryParse(pos.text) ?? 0);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _boxDropdown('Pump Number', pump, pumps, (v) => setState(() => pump = v!)),
          _boxDropdown('Fuel Type', fuel, fuels, (v) => setState(() => fuel = v!)),
          _boxField('Opening Reading', o),
          _boxField('Closing Reading', c),
          _boxField('Unit Price (₦)', p),
          _readonlyBox('Total Amount (₦)', total.toStringAsFixed(0), Colors.green),
        ])),
        const SizedBox(width: 30),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _boxField('Total Cash (₦)', cash),
          _boxField('Total POS (₦)', pos),
          _readonlyBox('Total Money (₦)', received.toStringAsFixed(0), received >= total ? Colors.green : Colors.red),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
            onPressed: (liters > 0 && received >= total)
                ? () { widget.onSaleRecorded(received); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale recorded!'), backgroundColor: Colors.green)); o.clear(); c.clear(); cash.clear(); pos.clear(); }
                : null,
            icon: const Icon(Icons.check_circle), label: const Text('Submit Sale'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          )),
        ])),
      ]),
    );
  }

  Widget _boxDropdown(String l, String v, List<String> i, Function(String?) f) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: DropdownButtonFormField<String>(value: v, decoration: InputDecoration(labelText: l, filled: true, fillColor: Colors.grey[850], border: OutlineInputBorder()), items: i.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: f));
  Widget _boxField(String l, TextEditingController ctrl) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l, filled: true, fillColor: Colors.grey[850], border: OutlineInputBorder()), onChanged: (_) => setState(() {})));
  Widget _readonlyBox(String l, String v, Color c) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(fontSize: 16)), Text('₦$v', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c))])));
}