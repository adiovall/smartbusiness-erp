import 'package:flutter/material.dart';

/* ===================== COLORS ===================== */

const panelBg = Color(0xFF0f172a);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);
const inputBorder = Color(0xFF334155);
const panelBorder = Color(0xFF1f2937);

class SaleTab extends StatefulWidget {
  /// Called when FINAL SUBMIT is done (batch).
  /// We'll pass totalSold (not cash/pos), so "Today's Sales" == sales value.
  final Function(double totalSold) onSaleRecorded;

  const SaleTab({super.key, required this.onSaleRecorded});

  @override
  State<SaleTab> createState() => _SaleTabState();
}

/* ===================== MODEL ===================== */

class PumpSale {
  final int pumpNo; // 1..12
  final String fuel; // Petrol (PMS) ...
  final double opening;
  final double closing;
  final double unitPrice;

  const PumpSale({
    required this.pumpNo,
    required this.fuel,
    required this.opening,
    required this.closing,
    required this.unitPrice,
  });

  double get liters => (closing - opening);
  double get amount => liters * unitPrice;
}

class _SaleTabState extends State<SaleTab> {
  final pumps = List.generate(12, (i) => 'Pump ${i + 1}');
  final fuels = ['Petrol (PMS)', 'Diesel (AGO)', 'Kerosene (HHK)', 'Gas (LPG)'];

  String pump = 'Pump 1';
  String fuel = 'Petrol (PMS)';

  // Input controllers (A)
  final oCtrl = TextEditingController();
  final cCtrl = TextEditingController();
  final priceCtrl = TextEditingController(text: '865');

  // Payment controllers (B)
  final cashCtrl = TextEditingController();
  final posCtrl = TextEditingController();

  // Recorded pumps list
  final List<PumpSale> recorded = [];

  // Editing state (index into recorded)
  int? editingIndex;

  // -------------------- computed --------------------

  double get opening => double.tryParse(oCtrl.text) ?? 0;
  double get closing => double.tryParse(cCtrl.text) ?? 0;
  double get unitPrice => double.tryParse(priceCtrl.text) ?? 0;

  double get liters => (closing - opening);
  double get amountSold => liters * unitPrice;

  double get totalSold =>
      recorded.fold(0.0, (sum, p) => sum + p.amount);

  double get received =>
      (double.tryParse(cashCtrl.text) ?? 0) + (double.tryParse(posCtrl.text) ?? 0);

  double get balance => received - totalSold;

  bool get canRecord =>
      liters > 0 && unitPrice > 0; // basic validation

  bool get canSubmit =>
      recorded.isNotEmpty && received >= totalSold && totalSold > 0;

  // -------------------- helpers --------------------

  String _abbrFuel(String full) {
    // Petrol (PMS) -> PMS
    final m = RegExp(r'\(([^)]+)\)').firstMatch(full);
    return m?.group(1) ?? full.split(' ').first;
  }

  String _money(double v) => v.toStringAsFixed(0);

  void _clearPumpInputs() {
    oCtrl.clear();
    cCtrl.clear();
    // keep unit price (often constant), but you can clear if you want
    setState(() => editingIndex = null);
  }

  void _undoAll() {
    recorded.clear();
    _clearPumpInputs();
    cashCtrl.clear();
    posCtrl.clear();
    setState(() {});
  }

  void _recordOrUpdatePump() {
    if (!canRecord) return;

    final pumpNo = int.tryParse(pump.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;

    final sale = PumpSale(
      pumpNo: pumpNo,
      fuel: fuel,
      opening: opening,
      closing: closing,
      unitPrice: unitPrice,
    );

    setState(() {
      if (editingIndex != null) {
        recorded[editingIndex!] = sale; // ✅ A: edit updates totals immediately
        editingIndex = null;
      } else {
        recorded.add(sale);
      }
    });

    _clearPumpInputs();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(editingIndex == null ? 'Pump recorded' : 'Pump updated'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _editPump(int index) {
    final p = recorded[index];
    setState(() {
      editingIndex = index;
      pump = 'Pump ${p.pumpNo}';
      fuel = p.fuel;
      oCtrl.text = p.opening.toStringAsFixed(0);
      cCtrl.text = p.closing.toStringAsFixed(0);
      priceCtrl.text = p.unitPrice.toStringAsFixed(0);
    });
  }

  void _deletePump(int index) {
    setState(() {
      if (editingIndex == index) {
        editingIndex = null;
        _clearPumpInputs();
      } else if (editingIndex != null && index < editingIndex!) {
        // keep edit pointer accurate if deleting rows above it
        editingIndex = editingIndex! - 1;
      }
      recorded.removeAt(index);
    });
  }

  // -------------------- UI --------------------

  InputDecoration _input(String label, {String? suffix}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffix,
      labelStyle: const TextStyle(color: textSecondary),
      suffixStyle: const TextStyle(color: textSecondary),
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  Widget _field(String label, TextEditingController ctrl, {String? suffix}) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: _input(label, suffix: suffix),
        style: const TextStyle(color: textPrimary),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _dropdown(String label, String v, List<String> items, Function(String?) f) {
    return SizedBox(
      height: 48,
      child: DropdownButtonFormField<String>(
        value: v,
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
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: textPrimary),
                ),
              ),
            )
            .toList(),
        onChanged: f,
      ),
    );
  }

  Widget _readonlyBox(String label, String value, Color color) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: inputBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '₦$value',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    TextStyle h = const TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w600);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: inputBorder),
      ),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text('Pump', style: h)),
          SizedBox(width: 52, child: Text('Fuel', style: h)),
          Expanded(child: Text('Liters', style: h)),
          Expanded(child: Text('Unit', style: h)),
          Expanded(child: Text('Amount', style: h)),
          const SizedBox(width: 70), // actions
        ],
      ),
    );
  }

  Widget _tableRow(PumpSale p, int index) {
    final isEditing = editingIndex == index;
    final fuelShort = _abbrFuel(p.fuel);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isEditing ? Colors.green.withOpacity(0.12) : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isEditing ? Colors.green.withOpacity(0.5) : panelBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text('P${p.pumpNo}', style: const TextStyle(color: textPrimary, fontSize: 12)),
          ),
          SizedBox(
            width: 52,
            child: Text(fuelShort, style: const TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(p.liters.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 12)),
          ),
          Expanded(
            child: Text(p.unitPrice.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              p.amount.toStringAsFixed(0),
              style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () => _editPump(index),
                  icon: const Icon(Icons.edit, size: 18),
                  color: textSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () => _deletePump(index),
                  icon: const Icon(Icons.delete, size: 18),
                  color: Colors.redAccent,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountColor = canRecord ? Colors.green : Colors.orange;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /* ===================== COLUMN A: INPUT + RECORDS ===================== */
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Record Pumps',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                const SizedBox(height: 12),

                // Row 1: Pump + Fuel
                Row(
                  children: [
                    Expanded(child: _dropdown('Pump No', pump, pumps, (v) => setState(() => pump = v!))),
                    const SizedBox(width: 10),
                    Expanded(child: _dropdown('Fuel Type', fuel, fuels, (v) => setState(() => fuel = v!))),
                  ],
                ),
                const SizedBox(height: 10),

                // Row 2: Opening + Closing
                Row(
                  children: [
                    Expanded(child: _field('Opening', oCtrl)),
                    const SizedBox(width: 10),
                    Expanded(child: _field('Closing', cCtrl)),
                  ],
                ),
                const SizedBox(height: 10),

                // Row 3: Unit + Amount Sold
                Row(
                  children: [
                    Expanded(child: _field('Unit Price', priceCtrl, suffix: '₦')),
                    const SizedBox(width: 10),
                    Expanded(child: _readonlyBox('Amount Sold', _money(amountSold), amountColor)),
                  ],
                ),

                const SizedBox(height: 12),

                // Row 4: Record + Pump count
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: canRecord ? _recordOrUpdatePump : null,
                          icon: Icon(editingIndex == null ? Icons.playlist_add : Icons.update),
                          label: Text(editingIndex == null ? 'Record Pump' : 'Update Pump'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            disabledBackgroundColor: Colors.green.withOpacity(0.35),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: inputBorder),
                      ),
                      child: Center(
                        child: Text(
                          'Total Pumps: ${recorded.length}',
                          style: const TextStyle(color: textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Row 5: Recorded pumps board
                _tableHeader(),
                const SizedBox(height: 10),

                Expanded(
                  child: recorded.isEmpty
                      ? Center(
                          child: Text(
                            'No pumps recorded yet.',
                            style: TextStyle(color: textSecondary),
                          ),
                        )
                      : ListView.separated(
                          itemCount: recorded.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _tableRow(recorded[i], i),
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 22),

          /* ===================== COLUMN B: SUMMARY + PAYMENT + SUBMIT ===================== */
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                const SizedBox(height: 12),

                // Total Sold big box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: inputBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount Sold', style: TextStyle(color: textSecondary)),
                      Text(
                        '₦${_money(totalSold)}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                _field('Cash', cashCtrl, suffix: '₦'),
                const SizedBox(height: 10),
                _field('POS', posCtrl, suffix: '₦'),

                const SizedBox(height: 12),

                _readonlyBox(
                  'Balance',
                  _money(balance),
                  balance >= 0 ? Colors.green : Colors.red,
                ),

                const Spacer(),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _undoAll,
                        icon: const Icon(Icons.undo),
                        label: const Text('Undo All'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textSecondary,
                          side: const BorderSide(color: inputBorder),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: canSubmit
                              ? () {
                                  // FINAL SUBMIT (batch)
                                  widget.onSaleRecorded(totalSold);

                                  _undoAll();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Batch sale submitted'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Submit Sale'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            disabledBackgroundColor: Colors.green.withOpacity(0.35),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
}
