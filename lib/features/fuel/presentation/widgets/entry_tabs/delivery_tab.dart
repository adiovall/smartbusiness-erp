// lib/features/fuel/presentation/widgets/entry_tabs/delivery_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '/../core/services/service_registry.dart';
import '/../core/models/delivery_record.dart' as core;

const panelBg = Color(0xFF111827);
const cardBg = Color(0xFF1F2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);
const inputBorder = Color(0xFF374151);

/* ===================== FORMATTER ===================== */
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
  final fuels = const ['PMS', 'AGO', 'DPK', 'Gas'];
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

  // ✅ today draft deliveries (persisted until submit)
  List<core.DeliveryRecord> _drafts = [];
  bool _loading = true;

  List<String> supplierSuggestions = [];
  bool _loadingSuppliers = true;

  bool get showSplit => source == 'External+Sales';

  double _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;

  double get salesPaid => showSplit ? _num(salesCtrl) : (source == 'Sales' ? _num(paidCtrl) : 0);
  double get externalPaid => showSplit ? _num(externalCtrl) : (source == 'External' ? _num(paidCtrl) : 0);
  double get amountPaid => showSplit ? salesPaid + externalPaid : _num(paidCtrl);

  double get totalLiters => _drafts.fold(0.0, (sum, r) => sum + r.liters);
  double get totalCost => _drafts.fold(0.0, (sum, r) => sum + r.totalCost);
  double get totalPaid => _drafts.fold(0.0, (sum, r) => sum + r.amountPaid);
  double get outstanding => totalCost - totalPaid;

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  // ✅ how much sales money is still available to pay deliveries today
  double _availableSalesMoney({String? editingId, double oldSalesPaid = 0}) {
    final sold = Services.sale.getDraftTotalAmount(); // ✅ add getter if missing
    final alreadyUsed = _drafts.fold(0.0, (s, d) => s + d.salesPaid);
    // when editing, add back the old value so user can keep same amount
    return sold - alreadyUsed + (editingId != null ? oldSalesPaid : 0);
  }

  @override
  void initState() {
    super.initState();
    _loadDraftToday();
    _loadSupplierSuggestions();
  }

  Future<void> _loadDraftToday() async {
    setState(() => _loading = true);
    final rows = await Services.deliveryRepo.fetchTodayDraft();
    if (!mounted) return;
    setState(() {
      _drafts = rows;
      _loading = false;
    });
  }

  Future<void> _loadSupplierSuggestions() async {
    setState(() => _loadingSuppliers = true);

    final set = <String>{};
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

  void _toast(String msg, {bool green = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: green ? Colors.green : Colors.red),
    );
  }

  void _clearInputsOnly() {
    supplierCtrl.clear();
    litersCtrl.clear();
    costCtrl.clear();
    paidCtrl.clear();
    salesCtrl.clear();
    externalCtrl.clear();
  }

  Future<void> _recordDraft() async {
    final supplier = supplierCtrl.text.trim();
    final liters = _num(litersCtrl);
    final cost = _num(costCtrl);

    if (supplier.isEmpty || liters <= 0 || cost <= 0) {
      _toast('Please fill Supplier, Liters and Total Cost correctly');
      return;
    }

    // ✅ Sales cap rule
    if (source == 'Sales' || source == 'External+Sales') {
      final maxSales = _availableSalesMoney();
      if (salesPaid > maxSales + 0.01) {
        _toast('Sales payment cannot exceed sold amount. Available: ${money.format(maxSales)}');
        return;
      }
    }

    // ✅ tank capacity warning (same as your old logic)
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
              'Current: ${commas.format(tank.currentLevel.toInt())}L\n\nProceed anyway?',
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
      final created = await Services.delivery.recordDraftDelivery(
        supplier: supplier,
        fuelType: selectedFuel,
        liters: liters,
        totalCost: cost,
        amountPaid: amountPaid,
        source: source,
        salesPaid: salesPaid,
        externalPaid: externalPaid,
      );

      setState(() => _drafts.insert(0, created));

      // ✅ DO NOT mark weekly summary yellow here (your rule)
      widget.onDeliveryRecorded(cost);

      // add supplier suggestion if new
      if (!supplierSuggestions.any((s) => s.toLowerCase() == supplier.toLowerCase())) {
        setState(() {
          supplierSuggestions = [...supplierSuggestions, supplier]
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        });
      }

      _clearInputsOnly();
      widget.onSubmitted();
      _toast('Recorded (Draft). You can still edit/delete until Submit.', green: true);
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<void> _deleteDraft(core.DeliveryRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: panelBg,
        title: const Text('Delete Draft?', style: TextStyle(color: textPrimary)),
        content: Text('Delete this draft delivery?\n${r.supplier} • ${r.fuelType}', style: const TextStyle(color: textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await Services.delivery.deleteDraftDelivery(r.id);
      setState(() => _drafts.removeWhere((x) => x.id == r.id));
      _toast('Deleted.', green: true);
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<void> _editDraft(core.DeliveryRecord r) async {
    final supCtrl = TextEditingController(text: r.supplier);
    String fuel = r.fuelType;
    String src = r.source;

    final litersE = TextEditingController(text: r.liters.toInt().toString());
    final costE = TextEditingController(text: r.totalCost.toInt().toString());

    final paidE = TextEditingController(text: r.amountPaid.toInt().toString());
    final salesE = TextEditingController(text: r.salesPaid.toInt().toString());
    final extE = TextEditingController(text: r.externalPaid.toInt().toString());

    bool split = src == 'External+Sales';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setM) {
          double num(TextEditingController c) =>
              double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;

          final salesPaidNew = split ? num(salesE) : (src == 'Sales' ? num(paidE) : 0);
          final externalPaidNew = split ? num(extE) : (src == 'External' ? num(paidE) : 0);

          final maxSales = _availableSalesMoney(editingId: r.id, oldSalesPaid: r.salesPaid);

          return AlertDialog(
            backgroundColor: panelBg,
            title: const Text('Edit Draft Delivery', style: TextStyle(color: textPrimary)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _textInput('Supplier', supCtrl),
                  const SizedBox(height: 8),

                  _drop('Fuel Type', fuel, fuels, (v) => setM(() => fuel = v!)),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(child: _numField('Liters', litersE)),
                      const SizedBox(width: 8),
                      Expanded(child: _numField('Total Cost (₦)', costE)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _drop('Source', src, sources, (v) {
                    setM(() {
                      src = v!;
                      split = src == 'External+Sales';
                      // clean fields
                      if (src == 'Sales') extE.clear();
                      if (src == 'External') salesE.clear();
                    });
                  }),
                  const SizedBox(height: 8),

                  if (!split) _numField('Amount Paid (₦)', paidE),
                  if (split) ...[
                    _numField('Sales (₦)', salesE),
                    const SizedBox(height: 8),
                    _numField('External (₦)', extE),
                  ],

                  const SizedBox(height: 8),
                  if (src == 'Sales' || src == 'External+Sales')
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sales available: ${money.format(maxSales)}',
                        style: const TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    ),

                  if ((src == 'Sales' || src == 'External+Sales') && salesPaidNew > maxSales + 0.01)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('⚠ Sales payment exceeds sold amount',
                            style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  // prevent invalid sales
                  if (src == 'Sales' || src == 'External+Sales') {
                    if (salesPaidNew > maxSales + 0.01) return;
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    try {
      final double liters = double.tryParse(litersE.text.replaceAll(',', '')) ?? 0.0;
      final double cost   = double.tryParse(costE.text.replaceAll(',', '')) ?? 0.0;

      double numV(TextEditingController c) =>
          double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0.0;

      final bool splitNow = src == 'External+Sales';

      final double salesPaidNew =
          splitNow ? numV(salesE) : (src == 'Sales' ? numV(paidE) : 0.0);

      final double externalPaidNew =
          splitNow ? numV(extE) : (src == 'External' ? numV(paidE) : 0.0);

      final double amountPaidNew =
          splitNow ? (salesPaidNew + externalPaidNew) : numV(paidE);

      final updated = await Services.delivery.editDraftDelivery(
        id: r.id,
        supplier: supCtrl.text.trim(),
        fuelType: fuel,
        liters: liters,
        totalCost: cost,
        amountPaid: amountPaidNew,
        source: src,
        salesPaid: salesPaidNew,
        externalPaid: externalPaidNew,
      );

      setState(() {
        final idx = _drafts.indexWhere((x) => x.id == r.id);
        if (idx != -1) _drafts[idx] = updated;
      });

      _toast('Updated.', green: true);
    } catch (e) {
      _toast('Error: $e');
    }

  }

  Future<void> _submitDeliveries() async {
    if (_drafts.isEmpty) return;

    try {
      // ✅ lock + debts become real (your service does this)
      await Services.delivery.submitDraftDeliveries(_drafts);

      // ✅ weekly summary yellow ONLY now (not on record)
      await Services.dayEntry.submitSection(
        businessDate: _todayKey(),
        section: 'Del',
        submittedAt: DateTime.now(),
      );

      setState(() => _drafts.clear());
      _clearInputsOnly();
      widget.onSubmitted();

      _toast('Delivery Submitted. Drafts locked.', green: true);
    } catch (e) {
      _toast('Error: $e');
    }
  }

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

  Widget _numField(String label, TextEditingController c) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          ThousandsSeparatorInputFormatter(locale: 'en_NG'),
        ],
        decoration: _input(label),
        style: const TextStyle(color: textPrimary),
      );

  Widget _textInput(String label, TextEditingController c) => TextField(
        controller: c,
        decoration: _input(label),
        style: const TextStyle(color: textPrimary),
      );

  Widget _drop(String label, String v, List<String> items, ValueChanged<String?> f) {
    return DropdownButtonFormField<String>(
      value: v,
      isDense: true,
      isExpanded: true,
      dropdownColor: panelBg,
      decoration: _input(label),
      items: items
          .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textPrimary)),
              ))
          .toList(),
      onChanged: f,
    );
  }

  Widget _supplierAutocomplete(String label, TextEditingController c) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return supplierSuggestions.where((s) => s.toLowerCase().startsWith(q)).take(12);
      },
      onSelected: (v) => c.text = v,
      fieldViewBuilder: (_, ctrl, focus, __) {
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
    );
  }

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
                const Text('Delivery Entry',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
                const SizedBox(height: 10),

                _supplierAutocomplete('Supplier', supplierCtrl),
                const SizedBox(height: 8),

                _drop('Fuel Type', selectedFuel, fuels, (v) => setState(() => selectedFuel = v!)),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(child: _numField('Liters', litersCtrl)),
                    const SizedBox(width: 8),
                    Expanded(child: _numField('Total Cost (₦)', costCtrl)),
                  ],
                ),

                const SizedBox(height: 14),
                const Text('Payment',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary)),
                const SizedBox(height: 8),

                _drop('Source', source, sources, (v) {
                  setState(() {
                    source = v!;
                    if (source == 'Sales') {
                      externalCtrl.clear();
                      salesCtrl.clear();
                    }
                    if (source == 'External') {
                      salesCtrl.clear();
                      externalCtrl.clear();
                    }
                  });
                }),

                const SizedBox(height: 8),

                if (!showSplit) _numField('Amount Paid (₦)', paidCtrl),
                if (showSplit) ...[
                  _numField('Sales (₦)', salesCtrl),
                  const SizedBox(height: 8),
                  _numField('External (₦)', externalCtrl),
                ],

                const SizedBox(height: 10),
                if (source == 'Sales' || source == 'External+Sales')
                  Text(
                    'Sales available: ${money.format(_availableSalesMoney())}',
                    style: const TextStyle(color: textSecondary, fontSize: 12),
                  ),

                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _recordDraft,
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('Record Delivery (Draft)'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 24),

          /* DRAFT LIST + SUBMIT */
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Today\'s Draft Deliveries (Editable until Submit)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
                const SizedBox(height: 12),

                _summaryRow('Total Liters', '${commas.format(totalLiters.toInt())} L'),
                _summaryRow('Total Cost', money.format(totalCost)),
                _summaryRow('Total Paid', money.format(totalPaid), color: Colors.green),
                _summaryRow('Outstanding', money.format(outstanding),
                    color: outstanding > 0 ? Colors.red : Colors.green),

                const SizedBox(height: 14),

                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _drafts.isEmpty
                          ? const Center(child: Text('No draft deliveries', style: TextStyle(color: textSecondary)))
                          : ListView.builder(
                              itemCount: _drafts.length,
                              itemBuilder: (_, i) {
                                final r = _drafts[i];

                                return Card(
                                  color: cardBg,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    title: Text('${r.supplier} • ${r.fuelType}', style: const TextStyle(color: textPrimary)),
                                    subtitle: Text(
                                      '${commas.format(r.liters.toInt())}L • ${money.format(r.totalCost)}'
                                      '${(r.salesPaid > 0 || r.externalPaid > 0) ? "  |  S:${money.format(r.salesPaid)}  E:${money.format(r.externalPaid)}" : ""}',
                                      style: const TextStyle(color: textSecondary),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit',
                                          icon: const Icon(Icons.edit, color: Colors.white70),
                                          onPressed: () => _editDraft(r),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete',
                                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                                          onPressed: () => _deleteDraft(r),
                                        ),
                                      ],
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
                        onPressed: _clearInputsOnly,
                        icon: const Icon(Icons.undo),
                        label: const Text('Clear Inputs'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _drafts.isNotEmpty ? _submitDeliveries : null,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Submit Delivery'),
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
