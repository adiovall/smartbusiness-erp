// lib/features/fuel/presentation/widgets/entry_tabs/delivery_tab.dart
import 'package:flutter/material.dart';

class DeliveryTab extends StatefulWidget {
  final VoidCallback onSubmitted;
  const DeliveryTab({super.key, required this.onSubmitted});
  @override State<DeliveryTab> createState() => _DeliveryTabState();
}

class _DeliveryTabState extends State<DeliveryTab> {
  final knownSuppliers = ['Micheal', 'Onyis Fuel', 'NNPC Depot', 'Val Oil', 'Total Energies'];
  final fuels = ['Petrol (PMS)', 'Diesel (AGO)', 'Kerosene (HHK)', 'Gas (LPG)'];
  final sources = ['External', 'Sales', 'External+Sales'];
  
  String fuel = 'Petrol (PMS)', source = 'External';
  final supplierCtrl = TextEditingController();
  final litersCtrl = TextEditingController(), costCtrl = TextEditingController(), paidCtrl = TextEditingController();
  final salesAmtCtrl = TextEditingController(), extAmtCtrl = TextEditingController();

  List<String> filtered = [];

  @override
  void initState() {
    super.initState();
    filtered = knownSuppliers;
    supplierCtrl.addListener(() {
      setState(() {
        final query = supplierCtrl.text.toLowerCase();
        filtered = knownSuppliers.where((s) => s.toLowerCase().contains(query)).toList();
      });
    });
  }

  bool get showSplit => source == 'External+Sales';
  double get balance => (double.tryParse(costCtrl.text) ?? 0) - (double.tryParse(paidCtrl.text) ?? 0);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Delivery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // AUTO-SUGGEST SUPPLIER
          Autocomplete<String>(
            optionsBuilder: (textEditingValue) => filtered,
            onSelected: (selection) => supplierCtrl.text = selection,
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextField(
              controller: supplierCtrl,
              focusNode: focusNode,
              decoration: const InputDecoration(labelText: 'Supplier Name', filled: true, border: OutlineInputBorder()),
            ),
          ),
          _boxDropdown('Fuel Type', fuel, fuels, (v) => setState(() => fuel = v!)),
          _boxField('Liters Received', litersCtrl),
          _boxField('Total Cost (₦)', costCtrl),
        ])),
        const SizedBox(width: 30),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Payment Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _boxField('Amount Paid (₦)', paidCtrl)),
            const SizedBox(width: 8),
            Expanded(child: _boxDropdown('Source', source, sources, (v) => setState(() => source = v!))),
          ]),
          if (showSplit) ...[_boxField('Sales Amount (₦)', salesAmtCtrl), _boxField('External Amount (₦)', extAmtCtrl)],
          _readonlyBox('Balance (Debt)', balance.toStringAsFixed(0), balance > 0 ? Colors.red : Colors.green),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
            onPressed: () { widget.onSubmitted(); },
            icon: const Icon(Icons.local_shipping), label: const Text('Submit Delivery'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          )),
        ])),
      ]),
    );
  }

  Widget _boxDropdown(
  String l,
  String v,
  List<String> i,
  Function(String?) f,
) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        value: v,
        isExpanded: true, // 🔥 IMPORTANT
        isDense: true, // 🔥 IMPORTANT
        decoration: InputDecoration(
          labelText: l,
          filled: true,
          fillColor: Colors.grey[850],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14, // 🔥 matches TextField height
          ),
          border: const OutlineInputBorder(),
        ),
        items: i
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(
                  e,
                  overflow: TextOverflow.ellipsis, // safety
                ),
              ),
            )
            .toList(),
        onChanged: f,
      ),
    );

  Widget _boxField(String l, TextEditingController c) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: TextField(
    controller: c,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: l,
      filled: true,
      fillColor: Colors.grey[850],
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      border: const OutlineInputBorder(),
    ),
    onChanged: (_) => setState(() {}),
  ),
);

  Widget _readonlyBox(String l, String v, Color c) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l), Text('₦$v', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c))])));
}