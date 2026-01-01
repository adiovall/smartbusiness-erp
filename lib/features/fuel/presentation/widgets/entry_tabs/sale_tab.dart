// lib/features/fuel/presentation/widgets/entry_tabs/sale_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/../core/services/service_registry.dart';

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

  double get liters => (closing - opening).clamp(0, double.infinity);
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

  String _abbrFuel(String full) {
    final m = RegExp(r'\(([^)]+)\)').firstMatch(full);
    return m?.group(1) ?? full.split(' ').first;
  }

  String _formatMoney(double v) {
    final parts = v.toStringAsFixed(0).split('.');
    final integer = parts[0].replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},');
    return integer;
  }

  double _parseNumber(String text) => double.tryParse(text.replaceAll(',', '')) ?? 0;

  double get opening => _parseNumber(oCtrl.text);
  double get closing => _parseNumber(cCtrl.text);
  double get unitPrice => _parseNumber(priceCtrl.text);
  double get liters => (closing - opening);
  double get amountSold => liters * unitPrice;

  double get totalSold => recorded.fold(0.0, (sum, p) => sum + p.amount);
  double get cash => _parseNumber(cashCtrl.text);
  double get pos => _parseNumber(posCtrl.text);
  double get moneyAtHand => cash + pos;
  double get balance => moneyAtHand - totalSold;

  bool get canRecord => liters > 0 && unitPrice > 0 && liters <= _availableLiters();
  bool get canSubmit => recorded.isNotEmpty;

  double _availableLiters() {
    final fuelCode = _abbrFuel(fuel);
    final tank = Services.tank.getTank(fuelCode);
    return tank?.currentLevel ?? 0.0;
  }

  void _clearPumpInputs() {
    oCtrl.clear();
    cCtrl.clear();
    setState(() => editingIndex = null);
  }

  void _undoAll() {
    for (final sale in recorded) {
      final fuelCode = _abbrFuel(sale.fuel);
      Services.tank.addFuel(fuelCode, sale.liters);
    }
    recorded.clear();
    _clearPumpInputs();
    cashCtrl.clear();
    posCtrl.clear();
    setState(() {});
  }

  Future<void> _recordOrUpdatePump() async {
    if (!canRecord) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not enough fuel in tank (${_availableLiters().toStringAsFixed(1)}L available)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final fuelCode = _abbrFuel(fuel);
    await Services.tank.removeFuel(fuelCode, liters);

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
      SnackBar(content: Text(editingIndex == null ? 'Pump recorded' : 'Pump updated'), backgroundColor: Colors.green),
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

  Future<void> _deletePump(int index) async {
    final p = recorded[index];
    final fuelCode = _abbrFuel(p.fuel);
    await Services.tank.addFuel(fuelCode, p.liters);

    setState(() {
      if (editingIndex == index) {
        editingIndex = null;
        _clearPumpInputs();
      }
      recorded.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pump deleted – fuel returned to tank')),
    );
  }

  Future<void> _submitWithBalanceCheck() async {
    if (balance.abs() < 0.01) {
      // Perfect tally
      widget.onSaleRecorded(totalSold);
      _undoAll();
      return;
    }

    if (balance > 0) {
      // Overpayment
      final bool? createCredit = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: panelBg,
          title: const Text('Overpayment Detected', style: TextStyle(color: Colors.blue)),
          content: Text(
            'Customer paid ₦${_formatMoney(balance)} more than sold.\n'
            'Create credit note?',
            style: const TextStyle(color: textSecondary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No, Cancel Submit')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, Submit with Credit'),
            ),
          ],
        ),
      );

      if (createCredit != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submit cancelled due to overpayment'), backgroundColor: Colors.orange),
        );
        return;
      }

      // TODO: Create credit note in debt/credit system when ready
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Overpayment ₦${_formatMoney(balance)} recorded as credit'), backgroundColor: Colors.blue),
      );
    } else {
      // Shortage
      final shortage = -balance;
      final bool? recordShortage = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: panelBg,
          title: const Text('Sales Shortage Detected', style: TextStyle(color: Colors.orange)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Shortage: ₦${_formatMoney(shortage)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: shortageCommentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Comment (required)',
                  border: OutlineInputBorder(),
                  hintText: 'Why was money short?',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel Submit')),
            ElevatedButton(
              onPressed: shortageCommentCtrl.text.trim().isEmpty ? null : () => Navigator.pop(context, true),
              child: const Text('Submit & Record Shortage'),
            ),
          ],
        ),
      );

      if (recordShortage != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submit cancelled'), backgroundColor: Colors.orange),
        );
        return;
      }

      await Services.expense.createExpense(
        amount: shortage,
        category: 'Sales Shortage',
        comment: shortageCommentCtrl.text.trim(),
        isLocked: true,
        source: 'Sales',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shortage ₦${_formatMoney(shortage)} recorded'), backgroundColor: Colors.orange),
      );
    }

    widget.onSaleRecorded(totalSold);
    _undoAll();
    shortageCommentCtrl.clear();
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
      enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: inputBorder), borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.green), borderRadius: BorderRadius.circular(8)),
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
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: inputBorder),
            ),
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
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
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: f,
    );
  }

  Widget _tableHeader() {
    TextStyle h = const TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w600);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 117, 157, 244).withOpacity(0.4),
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
          const SizedBox(width: 80), // Extra space for buttons
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
          SizedBox(width: 48, child: Text('P${p.pumpNo}', style: const TextStyle(color: textPrimary, fontSize: 12))),
          SizedBox(width: 52, child: Text(fuelShort, style: const TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
          Expanded(child: Text(p.liters.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 12))),
          Expanded(child: Text(p.unitPrice.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 12))),
          Expanded(child: Text('₦${_formatMoney(p.amount)}', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w700))),
          SizedBox(
            width: 80,
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
    final amountColor = canRecord ? Colors.green : Colors.red;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT: RECORD PUMPS
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Record Pumps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _dropdown('Pump No', pump, pumps, (v) => setState(() => pump = v!))),
                  const SizedBox(width: 10),
                  Expanded(child: _dropdown('Fuel Type', fuel, fuels, (v) => setState(() => fuel = v!))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _numberField('Opening', oCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _numberField('Closing', cCtrl)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _numberField('Unit Price', priceCtrl, suffix: '₦')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: inputBorder)),
                      alignment: Alignment.centerRight,
                      child: Text('₦${_formatMoney(amountSold)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: amountColor)),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
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
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: inputBorder)),
                    child: Center(child: Text('Total Pumps: ${recorded.length}', style: const TextStyle(color: textSecondary, fontWeight: FontWeight.w600))),
                  ),
                ]),
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

          // RIGHT: ACCOUNTS
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Accounts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
                const SizedBox(height: 16),

                _readonlyField(
                  label: 'Total Amount Sold',
                  value: '₦${_formatMoney(totalSold)}',
                  valueColor: Colors.green,
                ),


                const SizedBox(height: 20),
                const Text('Payment', style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),

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
                Text('Balance: ₦${_formatMoney(balance)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: balance >= 0 ? Colors.green : Colors.red)),

                const Spacer(),

                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: _undoAll, icon: const Icon(Icons.undo), label: const Text('Undo All'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canSubmit ? _submitWithBalanceCheck : null,
                      icon: const Icon(Icons.send),
                      label: const Text('Submit'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ),
                ]),
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