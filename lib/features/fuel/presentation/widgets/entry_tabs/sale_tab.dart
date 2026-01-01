// lib/features/fuel/presentation/widgets/entry_tabs/sale_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/../core/services/service_registry.dart';
import '../../../domain/fuel_mapping.dart';
import '../../../domain/sale_draft_engine.dart';

/* ===================== COLORS ===================== */
const panelBg = Color(0xFF0f172a);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);
const inputBorder = Color(0xFF334155);
const panelBorder = Color(0xFF1f2937);

class SaleTab extends StatefulWidget {
  final Function(double totalSold) onSaleRecorded;
  final VoidCallback onDraftMarked;

  const SaleTab({
    super.key,
    required this.onSaleRecorded,
    required this.onDraftMarked,
  });

  @override
  State<SaleTab> createState() => _SaleTabState();
}

class PumpSale {
  final int pumpNo;
  final String fuel;
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

  double get liters => (closing - opening).clamp(0.0, double.infinity).toDouble();
  double get amount => liters * unitPrice;
}

class _SaleTabState extends State<SaleTab> {
  final pumps = List.generate(12, (i) => 'Pump ${i + 1}');
  final fuels = ['Petrol (PMS)', 'Diesel (AGO)', 'Kerosene (HHK)', 'Gas (LPG)'];

  String pump = 'Pump 1';
  String fuel = 'Petrol (PMS)';

  final oCtrl = TextEditingController();
  final cCtrl = TextEditingController();
  final priceCtrl = TextEditingController(text: '865');
  final cashCtrl = TextEditingController();
  final posCtrl = TextEditingController();
  final shortageCommentCtrl = TextEditingController();

  final List<PumpSale> recorded = [];
  int? editingIndex;

  String _abbrFuel(String v) => FuelMapping.abbrFromLabel(v);

  double _parseNumber(String text) =>
      double.tryParse(text.replaceAll(',', '').trim()) ?? 0.0;

  String _formatMoney(double v) {
    return v
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  double get opening => _parseNumber(oCtrl.text);
  double get closing => _parseNumber(cCtrl.text);
  double get unitPrice => _parseNumber(priceCtrl.text);
  double get liters => closing - opening;
  double get amountSold => liters * unitPrice;

  double get totalSold => recorded.fold(0.0, (sum, p) => sum + p.amount);

  double get cash => _parseNumber(cashCtrl.text);
  double get pos => _parseNumber(posCtrl.text);
  double get moneyAtHand => cash + pos;
  double get balance => moneyAtHand - totalSold;

  double _availableLiters() {
    return SaleDraftEngine.availableLiters(
      selectedFuelLabel: fuel,
      recorded: recorded,
      editingIndex: editingIndex,
    );
  }

  bool get canRecord => liters > 0 && unitPrice > 0 && liters <= _availableLiters();
  bool get canSubmit => recorded.isNotEmpty;

  void _clearPumpInputs() {
    oCtrl.clear();
    cCtrl.clear();
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
    if (!canRecord) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not enough fuel (${_availableLiters().toStringAsFixed(1)} L available)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
        recorded[editingIndex!] = sale;
        editingIndex = null;
      } else {
        recorded.add(sale);
        widget.onDraftMarked();
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
      }
      recorded.removeAt(index);
    });
  }

  Future<void> _submitWithBalanceCheck() async {
    if (balance.abs() < 0.01) {
      await _applyTankConsumption();
      widget.onSaleRecorded(totalSold);
      _undoAll();
      shortageCommentCtrl.clear();
      return;
    }

    if (balance > 0) {
      final bool? createCredit = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: panelBg,
          title: const Text('Overpayment Detected', style: TextStyle(color: Colors.blue)),
          content: Text(
            'Customer paid ₦${_formatMoney(balance)} more than sold.\nCreate credit note?',
            style: const TextStyle(color: textSecondary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
          ],
        ),
      );

      if (createCredit != true) return;
    } else {
      final shortage = -balance;

      final bool? recordShortage = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            backgroundColor: panelBg,
            title: const Text('Sales Shortage', style: TextStyle(color: Colors.orange)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Shortage: ₦${_formatMoney(shortage)}',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: shortageCommentCtrl,
                  maxLines: 3,
                  onChanged: (_) => setLocal(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Comment (required)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: shortageCommentCtrl.text.trim().isEmpty ? null : () => Navigator.pop(ctx, true),
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      );

      if (recordShortage != true) return;

      await Services.expense.createExpense(
        amount: shortage,
        category: 'Sales Shortage',
        comment: shortageCommentCtrl.text.trim(),
        isLocked: true,
        source: 'Sales',
      );
    }

    await _applyTankConsumption();
    widget.onSaleRecorded(totalSold);
    _undoAll();
    shortageCommentCtrl.clear();
  }

  Future<void> _applyTankConsumption() async {
    await SaleDraftEngine.applyTankConsumption(recorded);
  }

  InputDecoration _input(String label, {String? suffix}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffix,
      labelStyle: const TextStyle(color: textSecondary),
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

  Widget _numberField(String label, TextEditingController ctrl, {String? suffix}) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _input(label, suffix: suffix),
      style: const TextStyle(color: textPrimary),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _readonlyField({
    required String label,
    required String value,
    Color valueColor = textPrimary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textSecondary)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: inputBorder),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: valueColor),
          ),
        ),
      ],
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
                child: Text(e, overflow: TextOverflow.ellipsis, maxLines: 1),
              ))
          .toList(),
      onChanged: f,
    );
  }

  // ✅ compact icon to prevent overflow in tight widths
  Widget _miniIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountColor = canRecord ? Colors.green : Colors.red;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT
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
                Row(
                  children: [
                    Expanded(child: _dropdown('Pump No', pump, pumps, (v) => setState(() => pump = v!))),
                    const SizedBox(width: 10),
                    Expanded(child: _dropdown('Fuel Type', fuel, fuels, (v) => setState(() => fuel = v!))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _numberField('Opening', oCtrl)),
                    const SizedBox(width: 10),
                    Expanded(child: _numberField('Closing', cCtrl)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _numberField('Unit Price', priceCtrl, suffix: '₦')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 48,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: inputBorder),
                        ),
                        child: Text(
                          '₦${_formatMoney(amountSold)}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: amountColor),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: canRecord ? _recordOrUpdatePump : null,
                        icon: Icon(editingIndex == null ? Icons.playlist_add : Icons.update),
                        label: Text(editingIndex == null ? 'Record Pump' : 'Update Pump'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
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
                _tableHeader(),
                const SizedBox(height: 10),
                Expanded(
                  child: recorded.isEmpty
                      ? const Center(child: Text('No pumps recorded yet.', style: TextStyle(color: textSecondary)))
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

          // RIGHT (overflow-safe; buttons stay horizontal)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Accounts',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
                        ),
                        const SizedBox(height: 16),
                        _readonlyField(
                          label: 'Total Amount Sold',
                          value: '₦${_formatMoney(totalSold)}',
                          valueColor: Colors.green,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Payment',
                          style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 12),
                        _numberField('Cash', cashCtrl, suffix: '₦'),
                        const SizedBox(height: 10),
                        _numberField('POS', posCtrl, suffix: '₦'),
                        const SizedBox(height: 20),
                        _readonlyField(
                          label: 'Money at Hand',
                          value: '₦${_formatMoney(moneyAtHand)}',
                          valueColor: Colors.cyan,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Balance: ₦${_formatMoney(balance)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: balance >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _undoAll,
                        label: const Text('Undo All'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: canSubmit ? _submitWithBalanceCheck : null,
                        // icon: const Icon(Icons.send),
                        label: const Text('Submit'),
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

  Widget _tableHeader() {
    const h = TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w600);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 117, 157, 244).withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: inputBorder),
      ),
      child: const Row(
        children: [
          SizedBox(width: 48, child: Text('Pump', style: h)),
          SizedBox(width: 52, child: Text('Fuel', style: h)),
          Expanded(child: Text('Liters', style: h)),
          Expanded(child: Text('Unit', style: h)),
          Expanded(child: Text('Amount', style: h)),
          SizedBox(width: 72), // ✅ match compact actions width
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
            child: Text(
              fuelShort,
              style: const TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(p.liters.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 12)),
          ),
          Expanded(
            child: Text(p.unitPrice.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              '₦${_formatMoney(p.amount)}',
              style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ✅ FIX: compact action cell (no overflow)
          SizedBox(
            width: 72,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _miniIcon(icon: Icons.edit, color: textSecondary, onTap: () => _editPump(index)),
                const SizedBox(width: 6),
                _miniIcon(icon: Icons.delete, color: Colors.redAccent, onTap: () => _deletePump(index)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    oCtrl.dispose();
    cCtrl.dispose();
    priceCtrl.dispose();
    cashCtrl.dispose();
    posCtrl.dispose();
    shortageCommentCtrl.dispose();
    super.dispose();
  }
}
