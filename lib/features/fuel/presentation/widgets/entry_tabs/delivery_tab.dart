// lib/features/fuel/presentation/widgets/entry_tabs/delivery_tab.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:temp_fuel_app/core/services/service_registry.dart';
import 'package:temp_fuel_app/core/models/delivery_record.dart' as core;

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

  final supplierCtrl = TextEditingController(); // logic controller
  TextEditingController? _supplierAutoCtrl;     // ✅ actual UI controller from Autocomplete

  final litersCtrl = TextEditingController();
  final costCtrl = TextEditingController();

  final paidCtrl = TextEditingController();     // single mode
  final salesCtrl = TextEditingController();    // split mode
  final externalCtrl = TextEditingController(); // split mode

  bool useOverpaid = false;

  double supplierOverpaidAvailable = 0.0; // remaining available (after drafts reserve)
  double creditUsedPreview = 0.0;

  // baseline cash values to restore when toggle OFF
  double _basePaidSingle = 0.0;
  double _basePaidSales = 0.0;
  double _basePaidExternal = 0.0;
  String _baseSource = 'External';

  String? editingId;
  double _editingOldSalesPaid = 0.0;
  double _editingOldCreditUsed = 0.0;

  List<core.DeliveryRecord> _drafts = [];
  bool _loading = true;

  // net sales
  bool _refreshingNet = false;
  double _todayNetSales = 0.0;

  // supplier suggestions
  List<String> supplierSuggestions = [];
  bool _loadingSuppliers = true;

  final money = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
  final commas = NumberFormat.decimalPattern('en_NG');

  bool get showSplit => source == 'External+Sales';

  double _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0.0;
  String _fmtInt(double v) => NumberFormat.decimalPattern('en_NG').format(v.round());

  double get salesPaid =>
      showSplit ? _num(salesCtrl) : (source == 'Sales' ? _num(paidCtrl) : 0.0);

  double get externalPaid =>
      showSplit ? _num(externalCtrl) : (source == 'External' ? _num(paidCtrl) : 0.0);

  double get amountPaid => showSplit ? (salesPaid + externalPaid) : _num(paidCtrl);

  double get totalLiters => _drafts.fold(0.0, (sum, r) => sum + r.liters);
  double get totalCost => _drafts.fold(0.0, (sum, r) => sum + r.totalCost);
  double get totalPaid => _drafts.fold(0.0, (sum, r) => sum + r.amountPaid);
  double get totalDebt => _drafts.fold(0.0, (sum, r) => sum + r.debt);
  double get totalOverpaid => _drafts.fold(0.0, (sum, r) => sum + r.credit);

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  bool get _usesSalesMoney => (source == 'Sales' || source == 'External+Sales');

  Future<void> _refreshNetSales() async {
    setState(() => _refreshingNet = true);

    // committed + draft
    final sales = await Services.sale.todayTotalAmount(includeDraft: true);
    final exp = Services.expense.todayTotal;
    final net = sales - exp;

    if (!mounted) return;
    setState(() {
      _todayNetSales = net < 0 ? 0.0 : net;
      _refreshingNet = false;
    });
  }

  double _availableSalesMoney({String? editingId, double oldSalesPaid = 0.0}) {
    final alreadyUsedInDrafts = _drafts.fold(0.0, (s, d) => s + d.salesPaid);
    final available = _todayNetSales - alreadyUsedInDrafts + (editingId != null ? oldSalesPaid : 0.0);
    return available < 0 ? 0.0 : available;
  }

  // ✅ reserve credit used by drafts so available reduces immediately
  double _draftCreditUsedForSupplier(String supplier, {String? excludeId}) {
    return _drafts
        .where((d) => d.supplier.toLowerCase() == supplier.toLowerCase())
        .where((d) => excludeId == null || d.id != excludeId)
        .fold(0.0, (s, d) => s + d.creditUsed);
  }

  double _availableSupplierCredit(String supplier) {
    final base = Services.delivery.totalCreditForSupplier(supplier);
    final reserved = _draftCreditUsedForSupplier(supplier, excludeId: editingId);
    final available = base - reserved + (editingId != null ? _editingOldCreditUsed : 0.0);
    return available < 0 ? 0.0 : available;
  }

  @override
  void initState() {
    super.initState();
    _loadDraftToday();
    _loadSupplierSuggestions();
    _refreshNetSales();

    supplierCtrl.addListener(_refreshOverpaidForSupplier);

    costCtrl.addListener(() {
      if (useOverpaid) _applyOverpaidFirstAndRebalance();
    });

    Services.expense.addListener(_onExpensesChanged);
  }

  void _onExpensesChanged() {
    if (!mounted) return;
    _refreshNetSales();
  }

  Future<void> _loadDraftToday() async {
    setState(() => _loading = true);
    final rows = await Services.deliveryRepo.fetchTodayDraft();
    if (!mounted) return;
    setState(() {
      _drafts = rows;
      _loading = false;
    });
    _refreshOverpaidForSupplier();
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

  void _setSupplierText(String v) {
    supplierCtrl.text = v;
    if (_supplierAutoCtrl != null) {
      _supplierAutoCtrl!.text = v;
      _supplierAutoCtrl!.selection = TextSelection.collapsed(offset: v.length);
    }
  }

  void _clearInputsOnly() {
    // ✅ clear supplier in BOTH controllers
    _setSupplierText('');

    litersCtrl.clear();
    costCtrl.clear();
    paidCtrl.clear();
    salesCtrl.clear();
    externalCtrl.clear();

    // ✅ clear toggle + previews
    useOverpaid = false;
    supplierOverpaidAvailable = 0.0;
    creditUsedPreview = 0.0;

    // reset baselines
    _basePaidSingle = 0.0;
    _basePaidSales = 0.0;
    _basePaidExternal = 0.0;
    _baseSource = source;

    editingId = null;
    _editingOldSalesPaid = 0.0;
    _editingOldCreditUsed = 0.0;

    setState(() {});
  }

  // ============================
  // OVERPAID: STRICT FIRST
  // ============================
  void _refreshOverpaidForSupplier() {
    final sup = supplierCtrl.text.trim();

    if (sup.isEmpty) {
      setState(() {
        supplierOverpaidAvailable = 0.0;
        useOverpaid = false;
        creditUsedPreview = 0.0;
      });
      return;
    }

    final available = _availableSupplierCredit(sup);

    setState(() {
      supplierOverpaidAvailable = available;
      if (available <= 0.0) {
        useOverpaid = false;
        creditUsedPreview = 0.0;
      }
    });

    if (useOverpaid) _applyOverpaidFirstAndRebalance();
  }

  void _captureBasePayments() {
    _baseSource = source;

    if (showSplit) {
      _basePaidSales = _num(salesCtrl);
      _basePaidExternal = _num(externalCtrl);
      _basePaidSingle = 0.0;
    } else {
      _basePaidSingle = _num(paidCtrl);
      _basePaidSales = 0.0;
      _basePaidExternal = 0.0;
    }
  }

  void _restoreBasePayments() {
    // If user changed source while ON, safest: clear payments
    if (_baseSource != source) {
      paidCtrl.clear();
      salesCtrl.clear();
      externalCtrl.clear();
      return;
    }

    if (showSplit) {
      salesCtrl.text = _fmtInt(_basePaidSales);
      externalCtrl.text = _fmtInt(_basePaidExternal);
      paidCtrl.clear();
    } else {
      paidCtrl.text = _fmtInt(_basePaidSingle);
      salesCtrl.clear();
      externalCtrl.clear();
    }
  }

  /// STRICT RULE:
  /// 1) Use overpaid FIRST (up to cost)
  /// 2) Remaining cost is paid by cash fields
  /// 3) If split: Sales first (bounded by available sales), then External
  void _applyOverpaidFirstAndRebalance() {
    final cost = _num(costCtrl);
    if (cost <= 0) return;

    final maxCredit = supplierOverpaidAvailable;
    final usedCredit = useOverpaid ? min(maxCredit, cost) : 0.0;
    final remaining = max(0.0, cost - usedCredit);

    final maxSales = _availableSalesMoney(editingId: editingId, oldSalesPaid: _editingOldSalesPaid);

    setState(() {
      creditUsedPreview = usedCredit;

      if (source == 'Sales') {
        final s = min(remaining, maxSales);
        paidCtrl.text = _fmtInt(s);
      } else if (source == 'External') {
        paidCtrl.text = _fmtInt(remaining);
      } else {
        final s = min(remaining, maxSales);
        final e = max(0.0, remaining - s);
        salesCtrl.text = _fmtInt(s);
        externalCtrl.text = _fmtInt(e);
      }
    });
  }

  // ============================
  // STRICT TANK CAPACITY CHECK
  // ============================
  bool _passesTankCapacityCheck({
    required String newFuelType,
    required double newLiters,
  }) {
    final tankNew = Services.tank.getTank(newFuelType);
    if (tankNew == null) return true;

    if (editingId == null) {
      final newLevel = tankNew.currentLevel + newLiters;
      if (newLevel > tankNew.capacity + 0.0001) {
        _toast(
          'Tank overflow: ${commas.format(newLiters.toInt())}L will exceed $newFuelType capacity '
          '(${commas.format(tankNew.capacity.toInt())}L). Update tank capacity first.',
        );
        return false;
      }
      return true;
    }

    final old = _drafts.firstWhere((x) => x.id == editingId, orElse: () => _drafts.first);
    final oldFuel = old.fuelType;
    final oldLiters = old.liters;

    if (oldFuel == newFuelType) {
      final delta = newLiters - oldLiters;
      if (delta <= 0) return true;

      final newLevel = tankNew.currentLevel + delta;
      if (newLevel > tankNew.capacity + 0.0001) {
        _toast(
          'Tank overflow: increase of ${commas.format(delta.toInt())}L will exceed $newFuelType capacity '
          '(${commas.format(tankNew.capacity.toInt())}L). Update tank capacity first.',
        );
        return false;
      }
      return true;
    }

    final newLevel = tankNew.currentLevel + newLiters;
    if (newLevel > tankNew.capacity + 0.0001) {
      _toast(
        'Tank overflow: ${commas.format(newLiters.toInt())}L will exceed $newFuelType capacity '
        '(${commas.format(tankNew.capacity.toInt())}L). Update tank capacity first.',
      );
      return false;
    }

    return true;
  }

  // ============================
  // EDIT / DELETE / SAVE
  // ============================
  void _startEdit(core.DeliveryRecord r) {
    setState(() {
      editingId = r.id;
      _editingOldSalesPaid = r.salesPaid;
      _editingOldCreditUsed = r.creditUsed;

      _setSupplierText(r.supplier);
      selectedFuel = r.fuelType;
      source = r.source;

      litersCtrl.text = _fmtInt(r.liters);
      costCtrl.text = _fmtInt(r.totalCost);

      if (r.source == 'External+Sales') {
        salesCtrl.text = _fmtInt(r.salesPaid);
        externalCtrl.text = _fmtInt(r.externalPaid);
        paidCtrl.clear();
      } else {
        paidCtrl.text = _fmtInt(r.amountPaid);
        salesCtrl.clear();
        externalCtrl.clear();
      }

      useOverpaid = r.creditUsed > 0;
      creditUsedPreview = r.creditUsed;

      supplierOverpaidAvailable = _availableSupplierCredit(r.supplier);

      // baseline for toggle OFF restore
      _captureBasePayments();
    });

    if (useOverpaid) _applyOverpaidFirstAndRebalance();
  }

  Future<void> _deleteDraft(core.DeliveryRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: panelBg,
        title: const Text('Delete Draft?', style: TextStyle(color: textPrimary)),
        content: Text(
          'Delete this draft delivery?\n${r.supplier} • ${r.fuelType}',
          style: const TextStyle(color: textSecondary),
        ),
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

      if (editingId == r.id) _clearInputsOnly();

      _toast('Deleted.', green: true);
      _refreshNetSales();
      _refreshOverpaidForSupplier();
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<void> _saveDraft() async {
    final supplier = supplierCtrl.text.trim();
    final liters = _num(litersCtrl);
    final cost = _num(costCtrl);

    if (supplier.isEmpty || liters <= 0 || cost <= 0) {
      _toast('Please fill Supplier, Liters and Total Cost correctly');
      return;
    }

    if (!_passesTankCapacityCheck(newFuelType: selectedFuel, newLiters: liters)) return;

    // enforce strict plan before validations
    if (useOverpaid) _applyOverpaidFirstAndRebalance();

    final maxSales =
        _availableSalesMoney(editingId: editingId, oldSalesPaid: _editingOldSalesPaid);

    if (_usesSalesMoney && salesPaid > maxSales + 0.01) {
      _toast('Sales payment cannot exceed Sales available. Available: ${money.format(maxSales)}');
      return;
    }

    final maxCredit = supplierOverpaidAvailable;
    final usedCredit = useOverpaid ? min(maxCredit, cost) : 0.0;

    try {
      core.DeliveryRecord saved;

      if (editingId == null) {
        saved = await Services.delivery.recordDraftDelivery(
          supplier: supplier,
          fuelType: selectedFuel,
          liters: liters,
          totalCost: cost,
          amountPaid: amountPaid,
          source: source,
          salesPaid: salesPaid,
          externalPaid: externalPaid,
          creditUsed: usedCredit,
        );

        setState(() => _drafts.insert(0, saved));
        widget.onDeliveryRecorded(cost);
        _toast('Recorded (Draft). Editable until Submit.', green: true);
      } else {
        saved = await Services.delivery.editDraftDelivery(
          id: editingId!,
          supplier: supplier,
          fuelType: selectedFuel,
          liters: liters,
          totalCost: cost,
          amountPaid: amountPaid,
          source: source,
          salesPaid: salesPaid,
          externalPaid: externalPaid,
          creditUsed: usedCredit,
        );

        setState(() {
          final idx = _drafts.indexWhere((x) => x.id == saved.id);
          if (idx != -1) _drafts[idx] = saved;
        });

        _toast('Updated.', green: true);
      }

      if (!supplierSuggestions.any((s) => s.toLowerCase() == supplier.toLowerCase())) {
        setState(() {
          supplierSuggestions = [...supplierSuggestions, supplier]
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        });
      }

      // ✅ IMPORTANT: clear all inputs + toggle for new input
      _clearInputsOnly();
      widget.onSubmitted();

      _refreshNetSales();
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<void> _submitDeliveries() async {
    if (_drafts.isEmpty) return;

    try {
      await Services.delivery.submitDraftDeliveries(_drafts);

      await Services.dayEntry.submitSection(
        businessDate: _todayKey(),
        section: 'Del',
        submittedAt: DateTime.now(),
      );

      setState(() => _drafts.clear());
      _clearInputsOnly();
      widget.onSubmitted();

      _toast('Delivery Submitted. Drafts locked.', green: true);
      _refreshNetSales();
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<void> _clearAllDrafts() async {
    if (_drafts.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: panelBg,
        title: const Text('Clear all drafts?', style: TextStyle(color: textPrimary)),
        content: const Text(
          'This will delete all draft deliveries and reverse tank changes.',
          style: TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final ids = _drafts.map((e) => e.id).toList();
      for (final id in ids) {
        await Services.delivery.deleteDraftDelivery(id);
      }
      setState(() => _drafts.clear());
      _clearInputsOnly();
      _toast('Drafts cleared.', green: true);
      _refreshNetSales();
    } catch (e) {
      _toast('Error: $e');
    }
  }

  // ============================
  // UI HELPERS
  // ============================
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
                child: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: textPrimary)),
              ))
          .toList(),
      onChanged: f,
    );
  }

  // ✅ supplier autocomplete (with safe clear + edit restore)
  Widget _supplierAutocomplete(String label) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return supplierSuggestions.where((s) => s.toLowerCase().startsWith(q)).take(12);
      },
      onSelected: (v) {
        _setSupplierText(v);
        _refreshOverpaidForSupplier();
      },
      fieldViewBuilder: (_, ctrl, focus, __) {
        _supplierAutoCtrl = ctrl;

        // keep UI field in sync if logic changed (edit / clear)
        if (ctrl.text != supplierCtrl.text) {
          ctrl.value = supplierCtrl.value;
        }

        return TextField(
          controller: ctrl,
          focusNode: focus,
          onChanged: (_) {
            supplierCtrl.value = ctrl.value;
            _refreshOverpaidForSupplier();
          },
          decoration: _input(label).copyWith(
            suffixIcon: _loadingSuppliers
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : const Icon(Icons.search, color: Colors.white54),
          ),
          style: const TextStyle(color: textPrimary),
        );
      },
    );
  }

  String _statusText(core.DeliveryRecord r) {
    if (r.debt > 0) return 'DEBT';
    if (r.credit > 0) return 'OVERPAID';
    return 'OK';
  }

  Color _statusColor(core.DeliveryRecord r) {
    if (r.debt > 0) return Colors.redAccent;
    if (r.credit > 0) return Colors.greenAccent;
    return Colors.white70;
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

  // ============================
  // BUILD
  // ============================
  @override
  Widget build(BuildContext context) {
    final maxSales = _availableSalesMoney(editingId: editingId, oldSalesPaid: _editingOldSalesPaid);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  editingId == null ? 'Delivery Entry' : 'Delivery Entry (Editing)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                const SizedBox(height: 10),

                _supplierAutocomplete('Supplier'),
                const SizedBox(height: 8),

                _drop('Fuel Type', selectedFuel, fuels, (v) {
                  setState(() => selectedFuel = v!);
                  if (useOverpaid) _applyOverpaidFirstAndRebalance();
                }),
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

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _drop('Source', source, sources, (v) {
                        setState(() {
                          source = v!;

                          // stop carry-over: clear payment fields + baseline
                          paidCtrl.clear();
                          salesCtrl.clear();
                          externalCtrl.clear();
                          _captureBasePayments();
                        });

                        if (useOverpaid) _applyOverpaidFirstAndRebalance();
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: _numField(
                        source == 'Sales'
                            ? 'Sales Amount (₦)'
                            : source == 'External'
                                ? 'External Amount (₦)'
                                : 'Sales Amount (₦)',
                        source == 'External+Sales' ? salesCtrl : paidCtrl,
                      ),
                    ),
                  ],
                ),

                if (source == 'External+Sales') ...[
                  const SizedBox(height: 8),
                  _numField('External Amount (₦)', externalCtrl),
                ],

                const SizedBox(height: 10),

                if (_usesSalesMoney)
                  Text(
                    _refreshingNet
                        ? 'Sales available: ...'
                        : 'Sales available: ${money.format(maxSales)}',
                    style: const TextStyle(color: textSecondary, fontSize: 12),
                  ),

                if (supplierOverpaidAvailable > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Overpaid available: ${money.format(supplierOverpaidAvailable)}',
                          style: const TextStyle(color: textSecondary, fontSize: 12),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.75,
                        child: Switch(
                          value: useOverpaid,
                          onChanged: (v) {
                            setState(() => useOverpaid = v);

                            if (v) {
                              _captureBasePayments();
                              _applyOverpaidFirstAndRebalance();
                            } else {
                              setState(() {
                                creditUsedPreview = 0.0;
                                _restoreBasePayments();
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],

                if (useOverpaid && creditUsedPreview > 0)
                  Text(
                    'Using overpaid: ${money.format(creditUsedPreview)}',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                  ),

                const SizedBox(height: 18),

                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 360,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _saveDraft,
                      icon: Icon(editingId == null ? Icons.local_shipping : Icons.save),
                      label: Text(editingId == null ? 'Record Draft' : 'Update Draft'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 24),

          // RIGHT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Draft Deliveries (${_drafts.length})",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                const SizedBox(height: 12),

                _summaryRow('Total Liters', '${commas.format(totalLiters.toInt())} L'),
                _summaryRow('Total Cost', money.format(totalCost)),
                _summaryRow('Total Paid', money.format(totalPaid), color: Colors.green),
                _summaryRow('Total Debt', money.format(totalDebt),
                    color: totalDebt > 0 ? Colors.redAccent : Colors.green),
                _summaryRow('Total Overpaid', money.format(totalOverpaid),
                    color: totalOverpaid > 0 ? Colors.greenAccent : Colors.white70),

                const SizedBox(height: 14),

                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _drafts.isEmpty
                          ? const Center(
                              child: Text('No draft deliveries', style: TextStyle(color: textSecondary)),
                            )
                          : ListView.builder(
                              itemCount: _drafts.length,
                              itemBuilder: (_, i) {
                                final r = _drafts[i];
                                final status = _statusText(r);

                                final sTxt = r.salesPaid > 0 ? money.format(r.salesPaid) : '₦0';
                                final eTxt = r.externalPaid > 0 ? money.format(r.externalPaid) : '₦0';
                                final oTxt = r.creditUsed > 0 ? money.format(r.creditUsed) : '₦0';

                                return Card(
                                  color: cardBg,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${r.supplier} • ${r.fuelType}',
                                            style: const TextStyle(color: textPrimary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          status,
                                          style: TextStyle(
                                            color: _statusColor(r),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${commas.format(r.liters.toInt())}L · ${money.format(r.totalCost)}',
                                            style: const TextStyle(color: textSecondary, fontSize: 12),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'S:$sTxt  |  E:$eTxt  |  O:$oTxt',
                                            style: const TextStyle(color: textSecondary, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit',
                                          icon: const Icon(Icons.edit, color: Colors.white70),
                                          onPressed: () => _startEdit(r),
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
                        onPressed: _drafts.isNotEmpty ? _clearAllDrafts : null,
                        icon: const Icon(Icons.delete_sweep),
                        label: const Text('Clear Drafts'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _drafts.isNotEmpty ? _submitDeliveries : null,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Submit Delivery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size.fromHeight(48),
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

  @override
  void dispose() {
    Services.expense.removeListener(_onExpensesChanged);
    supplierCtrl.removeListener(_refreshOverpaidForSupplier);

    supplierCtrl.dispose();
    litersCtrl.dispose();
    costCtrl.dispose();
    paidCtrl.dispose();
    salesCtrl.dispose();
    externalCtrl.dispose();

    super.dispose();
  }
}
