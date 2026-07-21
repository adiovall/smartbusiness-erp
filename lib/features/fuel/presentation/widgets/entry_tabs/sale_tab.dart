// lib/features/fuel/presentation/widgets/entry_tabs/sale_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:temp_fuel_app/core/models/sale_record.dart';
import 'package:temp_fuel_app/core/services/service_registry.dart';

import '../../../domain/fuel_mapping.dart';
import 'pump_settings_dialog.dart';

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

class DecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (!RegExp(r'^\d*\.?\d{0,3}$').hasMatch(text)) return oldValue;
    return newValue;
  }
}


class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  ThousandsSeparatorInputFormatter({String locale = 'en_NG'})
      : _format = NumberFormat.decimalPattern(locale);
  final NumberFormat _format;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final formatted = _format.format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _SaleTabState extends State<SaleTab> {
  final fuels = ['Petrol (PMS)', 'Diesel (AGO)', 'Kerosene (DPK)', 'Gas (LPG)'];

  // pump starts empty — resolved once pump config + fuel selection are known
  String pump = '';
  String fuel = 'Petrol (PMS)';

  final oCtrl = TextEditingController();
  final cCtrl = TextEditingController();
  final priceCtrl = TextEditingController(text: '865');
  final cashCtrl = TextEditingController();
  final posCtrl = TextEditingController();
  final shortageCommentCtrl = TextEditingController();

  String? editingId;
  bool _loading = true;

  String _abbrFuel(String v) => FuelMapping.abbrFromLabel(v);

  /// Pump numbers assigned to the currently selected fuel type, formatted
  /// as dropdown labels. Defensively includes the currently-selected
  /// `pump` value even if it's no longer in the config — e.g. when
  /// editing an old sale whose pump was later reassigned or removed —
  /// so the dropdown never ends up with a value that isn't in its items
  /// (which is exactly the class of crash fixed earlier in this app).
  List<String> get pumpOptions {
    final abbr = _abbrFuel(fuel);
    final nums = Services.pumpConfig.pumpNumbersForFuel(abbr);
    final opts = nums.map((n) => 'Pump $n').toList();
    if (pump.isNotEmpty && !opts.contains(pump)) {
      opts.add(pump);
    }
    return opts;
  }

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

  List<SaleRecord> get recorded => Services.sale.todayDrafts;

  double get totalSold => recorded.fold(0.0, (sum, p) => sum + p.totalAmount);

  double get cash => _parseNumber(cashCtrl.text);
  double get pos => _parseNumber(posCtrl.text);
  double get moneyAtHand => cash + pos;
  double get balance => moneyAtHand - totalSold;

  bool get canRecord => pump.isNotEmpty && liters > 0 && unitPrice > 0;
  bool get canSubmit => recorded.isNotEmpty;

  @override
  void initState() {
    super.initState();
    Services.sale.addListener(_refresh);
    Services.pumpConfig.addListener(_onPumpConfigChanged);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await Services.sale.refreshToday();
    if (!mounted) return;
    setState(() {
      _syncPumpDefault();
      _loading = false;
    });
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  void _onPumpConfigChanged() {
    if (!mounted) return;
    setState(() {
      _syncPumpDefault();
    });
  }

  /// Keeps `pump` valid whenever the available options change — e.g.
  /// after loading, after the pump settings dialog saves, or after a
  /// fuel type switch. Never leaves `pump` pointing at a value that
  /// isn't in the current options list (aside from the edit-safety
  /// fallback already handled in pumpOptions).
  void _syncPumpDefault() {
    final opts = pumpOptions;
    if (opts.isEmpty) {
      pump = '';
    } else if (!opts.contains(pump)) {
      pump = opts.first;
    }
  }

  void _onFuelChanged(String? v) {
    if (v == null) return;
    setState(() {
      fuel = v;
      final opts = pumpOptions; // reads the now-updated `fuel`
      pump = opts.isEmpty ? '' : opts.first;
    });
  }

  @override
  void dispose() {
    Services.sale.removeListener(_refresh);
    Services.pumpConfig.removeListener(_onPumpConfigChanged);
    oCtrl.dispose();
    cCtrl.dispose();
    priceCtrl.dispose();
    cashCtrl.dispose();
    posCtrl.dispose();
    shortageCommentCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg, {bool green = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: green ? Colors.green : Colors.red),
    );
  }

  void _clearPumpInputs() {
    oCtrl.clear();
    cCtrl.clear();
    setState(() => editingId = null);
  }

  Future<void> _undoAll() async {
    final drafts = List<SaleRecord>.from(recorded);
    for (final d in drafts) {
      try {
        await Services.sale.deleteDraftSale(d.id);
      } catch (_) {}
    }
    _clearPumpInputs();
    cashCtrl.clear();
    posCtrl.clear();
    setState(() {});
  }

  Future<void> _recordOrUpdatePump() async {
    if (!canRecord) {
      _toast('Enter valid opening, closing, and unit price');
      return;
    }

    final pumpNo = pump.replaceAll(RegExp(r'[^0-9]'), '');
    final fuelAbbr = _abbrFuel(fuel);

    try {
      if (editingId != null) {
        await Services.sale.editDraftSale(
          id: editingId!,
          pumpNo: pumpNo,
          fuelType: fuelAbbr,
          opening: opening,
          closing: closing,
          unitPrice: unitPrice,
        );
        _toast('Pump updated', green: true);
      } else {
        await Services.sale.recordDraftSale(
          pumpNo: pumpNo,
          fuelType: fuelAbbr,
          opening: opening,
          closing: closing,
          unitPrice: unitPrice,
        );
        _toast('Pump recorded', green: true);
      }

      _clearPumpInputs();
    } catch (e) {
      _toast('Error: $e');
    }
  }

  void _editPump(SaleRecord p) {
    if (p.isSubmitted) return;
    setState(() {
      editingId = p.id;
      fuel = FuelMapping.labelFromAbbr(p.fuelType);
      pump = 'Pump ${p.pumpNo}'; // pumpOptions' fallback keeps this valid
      oCtrl.text = p.opening.toStringAsFixed(0);
      cCtrl.text = p.closing.toStringAsFixed(0);
      priceCtrl.text = p.unitPrice.toStringAsFixed(0);
    });
  }

  Future<void> _deletePump(SaleRecord p) async {
    if (p.isSubmitted) return;
    try {
      await Services.sale.deleteDraftSale(p.id);
      if (editingId == p.id) _clearPumpInputs();
      _toast('Deleted', green: true);
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<void> _submitWithBalanceCheck() async {
    final drafts = List<SaleRecord>.from(recorded);
    if (drafts.isEmpty) return;

    final totalToReport = totalSold; 

    if (balance.abs() < 0.01) {
      await Services.sale.submitDraftSales(drafts);
      widget.onSaleRecorded(totalToReport);
      widget.onDraftMarked();
      cashCtrl.clear();
      posCtrl.clear();
      shortageCommentCtrl.clear();
      setState(() {});
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
        isSubmitted: false,
        source: 'Sales',
      );
    }

    await Services.sale.submitDraftSales(drafts);

    widget.onSaleRecorded(totalToReport);
    widget.onDraftMarked();
    cashCtrl.clear();
    posCtrl.clear();
    shortageCommentCtrl.clear();
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

  Widget _numberField(
      String label,
      TextEditingController ctrl, {
      String? suffix,
      bool useThousands = false,
      bool allowDecimal = false,
    }) {
      return TextField(
        controller: ctrl,
        keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
        inputFormatters: useThousands
            ? [ThousandsSeparatorInputFormatter()]
            : allowDecimal
                ? [DecimalInputFormatter()]
                : [FilteringTextInputFormatter.digitsOnly],
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

  Widget _dropdown(String label, String? v, List<String> items, Function(String?) f) {
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

  Future<void> _openPumpSettings() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const PumpSettingsDialog(),
    );
    if (saved == true && mounted) {
      setState(() => _syncPumpDefault());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final amountColor = canRecord ? Colors.green : Colors.red;
    final opts = pumpOptions;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Record Pumps',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
                    ),
                    IconButton(
                      tooltip: 'Configure Pumps',
                      icon: const Icon(Icons.settings, color: textSecondary, size: 20),
                      onPressed: _openPumpSettings,
                    ),
                  ],
                ),
                if (opts.isEmpty) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'No pumps configured for this fuel type. Tap the settings icon to add pumps.',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _dropdown(
                        'Pump No',
                        pump.isEmpty ? null : pump,
                        opts,
                        (v) => setState(() => pump = v ?? ''),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dropdown('Fuel Type', fuel, fuels, _onFuelChanged),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _numberField('Opening', oCtrl, allowDecimal: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _numberField('Closing', cCtrl, allowDecimal: true)),
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
                        icon: Icon(editingId == null ? Icons.playlist_add : Icons.update),
                        label: Text(editingId == null ? 'Record Pump' : 'Update Pump'),
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
                          itemBuilder: (_, i) => _tableRow(recorded[i]),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 22),
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
                        _numberField('Cash', cashCtrl, suffix: '₦', useThousands: true),
                        const SizedBox(height: 10),
                        _numberField('POS', posCtrl, suffix: '₦', useThousands: true),
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
          SizedBox(width: 72),
        ],
      ),
    );
  }

  Widget _tableRow(SaleRecord p) {
    final isEditing = editingId == p.id;
    final isEditable = !p.isSubmitted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isEditing ? Colors.green.withOpacity(0.12) : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isEditing
              ? Colors.green.withOpacity(0.5)
              : (p.isSubmitted ? Colors.redAccent.withOpacity(0.4) : panelBorder),
        ),
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
              p.fuelType,
              style: const TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(p.liters.toStringAsFixed(3), style: const TextStyle(color: textPrimary, fontSize: 12)),
          ),
          Expanded(
            child: Text(p.unitPrice.toStringAsFixed(0), style: const TextStyle(color: textPrimary, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              '₦${_formatMoney(p.totalAmount)}',
              style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 72,
            child: isEditable
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _miniIcon(icon: Icons.edit, color: textSecondary, onTap: () => _editPump(p)),
                      const SizedBox(width: 6),
                      _miniIcon(icon: Icons.delete, color: Colors.redAccent, onTap: () => _deletePump(p)),
                    ],
                  )
                : const Align(
                    alignment: Alignment.centerRight,
                    child: Icon(Icons.lock, color: Colors.grey, size: 18),
                  ),
          ),
        ],
      ),
    );
  }
}