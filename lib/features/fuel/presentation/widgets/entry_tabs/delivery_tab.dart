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

 class _CreditPlan {
    final double creditUsed;
    final double salesAfter;
    final double externalAfter;

    const _CreditPlan({
      required this.creditUsed,
      required this.salesAfter,
      required this.externalAfter,
    });

    double get paymentAfter => salesAfter + externalAfter;
    double get effectivePaid => paymentAfter + creditUsed;
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

  // IMPORTANT:
  // supplierCtrl = logic controller (used in calculations)
  // _supplierAutoCtrl = the visible autocomplete TextField controller
  final supplierCtrl = TextEditingController();
  TextEditingController? _supplierAutoCtrl;

  final litersCtrl = TextEditingController();
  final costCtrl = TextEditingController();

  final paidCtrl = TextEditingController(); // single mode
  final salesCtrl = TextEditingController(); // split mode
  final externalCtrl = TextEditingController(); // split mode

  bool useOverpaid = false;

  // supplier credit available (ALREADY RESERVED BY OTHER DRAFTS REMOVED)
  double supplierOverpaidAvailable = 0.0;

  // how much credit will be used (preview + saved)
  double creditUsedPreview = 0.0;

  // editing
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
  bool get _usesSalesMoney => (source == 'Sales' || source == 'External+Sales');

  double _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0.0;
  String _fmtInt(double v) => NumberFormat.decimalPattern('en_NG').format(v.round());

  double get salesPaid => showSplit ? _num(salesCtrl) : (source == 'Sales' ? _num(paidCtrl) : 0.0);
  double get externalPaid => showSplit ? _num(externalCtrl) : (source == 'External' ? _num(paidCtrl) : 0.0);
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

  /* ===================== NET SALES ===================== */
  Future<void> _refreshNetSales() async {
    setState(() => _refreshingNet = true);

    // committed + draft (so Delivery sees sales even before submit)
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

  /* ===================== LIFECYCLE ===================== */
  @override
  void initState() {
    super.initState();
    _loadDraftToday();
    _loadSupplierSuggestions();
    _refreshNetSales();

    supplierCtrl.addListener(_refreshOverpaidForSupplier);

    // If cost changes while toggle is ON, re-apply credit plan
    costCtrl.addListener(() {
      if (useOverpaid) _applyCreditPlanAndUpdateFields();
    });

    // Keep net sales updating when expenses change
    Services.expense.addListener(_onExpensesChanged);
  }

  void _onExpensesChanged() {
    if (!mounted) return;
    _refreshNetSales();
    if (useOverpaid) _applyCreditPlanAndUpdateFields();
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

  /* ===================== CLEAR INPUTS ===================== */
  void _clearInputsOnly() {
    // Clear supplier BOTH controllers
    supplierCtrl.clear();
    _supplierAutoCtrl?.clear();

    litersCtrl.clear();
    costCtrl.clear();
    paidCtrl.clear();
    salesCtrl.clear();
    externalCtrl.clear();

    // Reset overpaid + previews
    useOverpaid = false;
    supplierOverpaidAvailable = 0.0;
    creditUsedPreview = 0.0;

    // Reset edit state
    editingId = null;
    _editingOldSalesPaid = 0.0;
    _editingOldCreditUsed = 0.0;

    setState(() {});
  }

  /* ===================== OVERPAID AVAILABILITY (RESERVE DRAFTS) ===================== */
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

    // Base credit from submitted rows only
    final base = Services.delivery.totalCreditForSupplier(sup);

    // Reserve credit already used by TODAY drafts for same supplier (so availability reduces immediately)
    final reservedByDrafts = _drafts
        .where((d) => d.supplier.trim().toLowerCase() == sup.toLowerCase())
        .fold(0.0, (s, d) => s + d.creditUsed);

    // If editing, "free back" the credit of the draft being edited (so it doesn't double-reserve)
    final reservedByOthers = (editingId != null) ? max(0.0, reservedByDrafts - _editingOldCreditUsed) : reservedByDrafts;

    final available = base - reservedByOthers;

    setState(() {
      supplierOverpaidAvailable = available < 0 ? 0.0 : available;

      // Hide toggle if no credit
      if (supplierOverpaidAvailable <= 0) {
        useOverpaid = false;
        creditUsedPreview = 0.0;
      }
    });

    if (useOverpaid) {
      _applyCreditPlanAndUpdateFields();
    }
  }

  /* ===================== CREDIT PLAN (THE BEHAVIOUR YOU ASKED) ===================== */
 

  _CreditPlan _computeCreditPlan({
    required double cost,
    required double baseSales,
    required double baseExternal,
    required double maxCredit,
    required double maxSalesAvailable,
    required bool allowSales,
    required bool allowExternal,
  }) {
    if (cost <= 0) {
      return const _CreditPlan(creditUsed: 0.0, salesAfter: 0.0, externalAfter: 0.0);
    }

    final basePayment = max(0.0, baseSales + baseExternal);
    final creditCap = min(maxCredit, cost); // can't use credit > cost

    // If even with all credit we still can't reach cost:
    // ✅ Use all credit, but DO NOT reduce payments (never make the debt worse)
    if (basePayment + creditCap < cost - 0.0001) {
      // Keep payments as user entered
      var s = allowSales ? baseSales : 0.0;
      var e = allowExternal ? baseExternal : 0.0;

      // sales cannot exceed available
      if (allowSales && s > maxSalesAvailable) {
        final overflow = s - maxSalesAvailable;
        s = maxSalesAvailable;
        if (allowExternal) {
          e += overflow; // shift overflow to external if possible
        }
      }

      return _CreditPlan(
        creditUsed: creditCap,
        salesAfter: s,
        externalAfter: e,
      );
    }

    // We can fully cover the cost with payment + credit.
    // ✅ Use maximum credit to reduce payments as much as possible.
    final creditUsed = creditCap;
    final paymentAfter = max(0.0, cost - creditUsed);

    // We must reduce basePayment down to paymentAfter.
    // Your rule: reduce SALES burden first, then external.
    final reduction = max(0.0, basePayment - paymentAfter);

    double sAfter = allowSales ? max(0.0, baseSales - reduction) : 0.0;
    double remainingReduction = max(0.0, reduction - (allowSales ? baseSales : 0.0));
    double eAfter = allowExternal ? max(0.0, baseExternal - remainingReduction) : 0.0;

    // sales cap enforcement (shift to external if needed)
    if (allowSales && sAfter > maxSalesAvailable) {
      final overflow = sAfter - maxSalesAvailable;
      sAfter = maxSalesAvailable;
      if (allowExternal) eAfter += overflow;
    }

    return _CreditPlan(
      creditUsed: creditUsed,
      salesAfter: sAfter,
      externalAfter: eAfter,
    );
  }

  void _applyCreditPlanAndUpdateFields() {
    final cost = _num(costCtrl);
    if (cost <= 0) return;

    final sup = supplierCtrl.text.trim();
    if (sup.isEmpty) return;

    final maxSales = _availableSalesMoney(editingId: editingId, oldSalesPaid: _editingOldSalesPaid);
    final maxCredit = supplierOverpaidAvailable;

    // Base amounts = current fields (when you toggle ON, you’re asking it to rebalance FROM CURRENT)
    double baseSales = 0.0;
    double baseExternal = 0.0;

    if (source == 'Sales') {
      baseSales = _num(paidCtrl);
      baseExternal = 0.0;
    } else if (source == 'External') {
      baseSales = 0.0;
      baseExternal = _num(paidCtrl);
    } else {
      baseSales = _num(salesCtrl);
      baseExternal = _num(externalCtrl);
    }

    final plan = _computeCreditPlan(
      cost: cost,
      baseSales: baseSales,
      baseExternal: baseExternal,
      maxCredit: maxCredit,
      maxSalesAvailable: maxSales,
      allowSales: _usesSalesMoney,
      allowExternal: (source != 'Sales'),
    );

    setState(() {
      creditUsedPreview = plan.creditUsed;

      if (source == 'Sales') {
        paidCtrl.text = _fmtInt(plan.salesAfter);
      } else if (source == 'External') {
        paidCtrl.text = _fmtInt(plan.externalAfter);
      } else {
        salesCtrl.text = _fmtInt(plan.salesAfter);
        externalCtrl.text = _fmtInt(plan.externalAfter);
      }
    });
  }

  /* ===================== STRICT TANK CAPACITY CHECK ===================== */
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

  /* ===================== EDIT / DELETE / SAVE ===================== */
  void _startEdit(core.DeliveryRecord r) {
    setState(() {
      editingId = r.id;
      _editingOldSalesPaid = r.salesPaid;
      _editingOldCreditUsed = r.creditUsed;

      // Supplier: update both controllers
      supplierCtrl.text = r.supplier;
      _supplierAutoCtrl?.text = r.supplier;

      selectedFuel = r.fuelType;
      source = r.source;

      litersCtrl.text = _fmtInt(r.liters);
      costCtrl.text = _fmtInt(r.totalCost);

      if (r.source == 'External+Sales') {
        salesCtrl.text = _fmtInt(r.salesPaid);
        externalCtrl.text = _fmtInt(r.externalPaid);
        paidCtrl.clear();
      } else if (r.source == 'Sales') {
        paidCtrl.text = _fmtInt(r.salesPaid); // keep consistent
        salesCtrl.clear();
        externalCtrl.clear();
      } else {
        paidCtrl.text = _fmtInt(r.externalPaid);
        salesCtrl.clear();
        externalCtrl.clear();
      }

      useOverpaid = r.creditUsed > 0;
      creditUsedPreview = r.creditUsed;
    });

    _refreshOverpaidForSupplier();

    // If overpaid was used, we want the toggle ON and the fields consistent
    if (useOverpaid) {
      _applyCreditPlanAndUpdateFields();
    }
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

      // refresh availability after delete (reserved credit released)
      _refreshOverpaidForSupplier();
      _refreshNetSales();
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

    // If toggle ON, rebalance once more before validation/save
    if (useOverpaid) _applyCreditPlanAndUpdateFields();

    // sales cap check
    final maxSales = _availableSalesMoney(editingId: editingId, oldSalesPaid: _editingOldSalesPaid);
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
          creditUsed: useOverpaid ? creditUsedPreview : 0.0, // ✅ truth
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
          creditUsed: useOverpaid ? creditUsedPreview : 0.0, // ✅ truth
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

      // ✅ IMPORTANT: after record, CLEAR EVERYTHING for new input
      _clearInputsOnly();
      widget.onSubmitted();

      // refresh because drafts affect both available sales and reserved overpaid
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

      // after submit, credit is truly consumed in backend (consumeCredit)
      _refreshNetSales();
      _refreshOverpaidForSupplier();
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

      // refresh because reserved credit is released
      _refreshNetSales();
      _refreshOverpaidForSupplier();
    } catch (e) {
      _toast('Error: $e');
    }
  }

  /* ===================== UI HELPERS ===================== */
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

  Widget _numField(String label, TextEditingController c, {VoidCallback? onChanged}) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          ThousandsSeparatorInputFormatter(locale: 'en_NG'),
        ],
        decoration: _input(label),
        style: const TextStyle(color: textPrimary),
        onChanged: (_) {
          if (useOverpaid) _applyCreditPlanAndUpdateFields();
          onChanged?.call();
        },
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

  // ✅ supplier autocomplete (FIXES your red line by declaring _supplierAutoCtrl above)
  Widget _supplierAutocomplete(String label, TextEditingController c) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return supplierSuggestions.where((s) => s.toLowerCase().startsWith(q)).take(12);
      },
      onSelected: (v) {
        // ✅ update BOTH: UI ctrl + logic ctrl
        _supplierAutoCtrl?.text = v;
        c.text = v;
        _refreshOverpaidForSupplier();
      },
      fieldViewBuilder: (_, ctrl, focus, __) {
        _supplierAutoCtrl = ctrl;

        // sync logic controller to what's visible
        if (c.text != ctrl.text) c.value = ctrl.value;

        return TextField(
          controller: ctrl,
          focusNode: focus,
          onChanged: (_) {
            if (c.text != ctrl.text) c.value = ctrl.value;
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

  /* ===================== BUILD ===================== */
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

                _supplierAutocomplete('Supplier', supplierCtrl),
                const SizedBox(height: 8),

                _drop('Fuel Type', selectedFuel, fuels, (v) {
                  setState(() => selectedFuel = v!);
                  if (useOverpaid) _applyCreditPlanAndUpdateFields();
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

                          // stop carry-over: clear payment fields when switching
                          paidCtrl.clear();
                          salesCtrl.clear();
                          externalCtrl.clear();

                          // reset toggle + preview when changing source
                          useOverpaid = false;
                          creditUsedPreview = 0.0;
                        });

                        _refreshOverpaidForSupplier();
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

                // sales available (only when relevant)
                if (_usesSalesMoney)
                  Text(
                    _refreshingNet ? 'Sales available: ...' : 'Sales available: ${money.format(maxSales)}',
                    style: const TextStyle(color: textSecondary, fontSize: 12),
                  ),

                const SizedBox(height: 10),

                // Overpaid toggle only if supplier has credit
                if (supplierOverpaidAvailable > 0) ...[
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
                              _applyCreditPlanAndUpdateFields();
                            } else {
                              setState(() => creditUsedPreview = 0.0);
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
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${r.supplier} • ${r.fuelType}',
                                            style: const TextStyle(color: textPrimary),
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
                                            style: const TextStyle(color: textSecondary),
                                          ),
                                          const SizedBox(height: 2),
                                          Text('S:$sTxt  |  E:$eTxt  |  O:$oTxt',
                                              style: const TextStyle(color: textSecondary)),
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
