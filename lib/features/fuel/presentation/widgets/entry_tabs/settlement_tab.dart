// lib/features/fuel/presentation/widgets/entry_tabs/settlement_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import 'package:temp_fuel_app/core/services/service_registry.dart';
import 'package:temp_fuel_app/core/models/debt_record.dart' as coredebt;
import 'package:temp_fuel_app/core/models/delivery_record.dart' as coredel;

/* ===================== COLORS ===================== */
const panelBg = Color(0xFF111827);
const panelBorder = Color(0xFF1f2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);
const inputBorder = Color(0xFF334155);
const cardBg = Color(0xFF1F2937);

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

/* ===================== OUTSTANDING ITEM (Debt or Credit) ===================== */
enum OutstandingType { debt, credit }

class OutstandingItem {
  final OutstandingType type;
  final String id;
  final String supplier;
  final String fuelType;
  final double amount; // debt amount OR remaining credit
  final DateTime date;

  const OutstandingItem({
    required this.type,
    required this.id,
    required this.supplier,
    required this.fuelType,
    required this.amount,
    required this.date,
  });
}

/* ===================== WIDGET ===================== */
class SettlementTab extends StatefulWidget {
  final VoidCallback onSubmitted;
  const SettlementTab({super.key, required this.onSubmitted});

  @override
  State<SettlementTab> createState() => _SettlementTabState();
}

class _SettlementTabState extends State<SettlementTab> {
  final fuels = const ['PMS', 'AGO', 'DPK', 'Gas'];
  final sources = const ['Sales', 'External', 'Sales+External'];

  String supplier = '';
  String fuelType = 'PMS';
  String source = 'Sales';

  final salesCtrl = TextEditingController();
  final extCtrl = TextEditingController();

  // selection lock (only one debt selectable until Undo)
  coredebt.DebtRecord? selectedDebt;

  // Part B (today delivery history)
  bool _loadingToday = true;
  List<coredel.DeliveryRecord> _todayDeliveries = [];

  // credits list (remaining overpaid credits from DB)
  bool _loadingCredits = true;
  List<coredel.DeliveryRecord> _credits = [];

  // net sales available (like delivery)
  bool _refreshingSales = false;
  double _todayNetSales = 0.0;

  String filterSupplier = 'All';
  String filterFuel = 'All';
  String filterSource = 'All';

  final money = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
  final commas = NumberFormat.decimalPattern('en_NG');

  String get _todayKey => DateTime.now().toIso8601String().split('T').first;
  bool get split => source == 'Sales+External';

  double _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0.0;

  double get salesPaid => split ? _num(salesCtrl) : (source == 'Sales' ? _num(salesCtrl) : 0.0);
  double get externalPaid => split ? _num(extCtrl) : (source == 'External' ? _num(extCtrl) : 0.0);
  double get totalPaid => salesPaid + externalPaid;

  bool get _usesSalesMoney => (source == 'Sales' || source == 'Sales+External');

  List<coredebt.DebtRecord> get debts => Services.debt.allDebts.where((d) => !d.settled).toList();

  // Build outstanding list: Debts + Credits (remaining)
  List<OutstandingItem> get outstandingList {
    final out = <OutstandingItem>[];

    // debts
    for (final d in debts) {
      // ASSUMPTION: your DebtRecord has `date` field (common in your codebase)
      // If it doesn't, change `d.date` to whatever field you store.
      final DateTime dt = d.createdAt; // or d.date (now supported)


      out.add(OutstandingItem(
        type: OutstandingType.debt,
        id: d.id,
        supplier: d.supplier,
        fuelType: d.fuelType,
        amount: d.amount,
        date: dt,
      ));
    }

    // credits (remaining overpaid)
    for (final c in _credits) {
      if (c.credit <= 0) continue;
      out.add(OutstandingItem(
        type: OutstandingType.credit,
        id: c.id,
        supplier: c.supplier,
        fuelType: c.fuelType,
        amount: c.credit, // remaining credit
        date: c.date,
      ));
    }

    // newest first
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  double get totalDebtAmount => debts.fold(0.0, (s, d) => s + d.amount);
  double get totalCreditRemaining => _credits.fold(0.0, (s, r) => s + (r.credit > 0 ? r.credit : 0.0));

  List<coredel.DeliveryRecord> get filteredToday {
    return _todayDeliveries.where((d) {
      final okSupplier = filterSupplier == 'All' || d.supplier == filterSupplier;
      final okFuel = filterFuel == 'All' || d.fuelType == filterFuel;
      final okSource = filterSource == 'All' || d.source == filterSource;
      return okSupplier && okFuel && okSource;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadTodayDeliveries();
    _loadCredits();
    _refreshNetSales();
  }

  Future<void> _refreshNetSales() async {
    setState(() => _refreshingSales = true);

    final sales = await Services.sale.todayTotalAmount(includeDraft: true);
    final exp = Services.expense.todayTotal;
    final net = sales - exp;

    if (!mounted) return;
    setState(() {
      _todayNetSales = net < 0 ? 0.0 : net;
      _refreshingSales = false;
    });
  }

  double _availableSalesMoney() {
    // settlement uses sales pool directly (already considers drafts because includeDraft true)
    final available = _todayNetSales;
    return available < 0 ? 0.0 : available;
  }

  Future<void> _loadTodayDeliveries() async {
    setState(() => _loadingToday = true);
    final rows = await Services.deliveryRepo.fetchTodaySubmitted();
    if (!mounted) return;
    setState(() {
      _todayDeliveries = rows;
      _loadingToday = false;
    });
  }

  Future<void> _loadCredits() async {
    setState(() => _loadingCredits = true);

    // We use DeliveryRepo.fetchAll then filter submitted credits
    // Credit rows are created by addCredit() in DeliveryService (liters=0, totalCost=0, credit>0, isSubmitted=1)
    final all = await Services.deliveryRepo.fetchAll();
    final credits = all.where((d) => d.isSubmitted == 1 && d.credit > 0).toList();

    if (!mounted) return;
    setState(() {
      _credits = credits;
      _loadingCredits = false;
    });
  }

  /* ===================== ACTIONS ===================== */

  Future<void> _settle() async {
    if (selectedDebt == null) {
      _toast('Click a debt to settle first');
      return;
    }

    if (totalPaid <= 0) {
      _toast('Enter settlement amount');
      return;
    }

    // sales cap check
    final maxSales = _availableSalesMoney();
    if (_usesSalesMoney && salesPaid > maxSales + 0.01) {
      _toast('Sales payment cannot exceed Sales available. Available: ${money.format(maxSales)}');
      return;
    }

    try {
      // Your settlement service should mark debt settled and create credit if overpaid.
      await Services.settlement.settleSplit(
        supplier: supplier.trim(),
        fuelType: fuelType,
        salesPaid: salesPaid,
        externalPaid: externalPaid,
        source: source,
      );

      widget.onSubmitted();

      _undo();

      // refresh lists: debts, credits, sales, deliveries
      await _loadCredits();
      await _refreshNetSales();
      await _loadTodayDeliveries();

      if (!mounted) return;
      _toast('Settled successfully', green: true);

      setState(() {});
    } catch (e) {
      _toast('Error: $e');
    }
  }

  void _undo() {
    salesCtrl.clear();
    extCtrl.clear();
    selectedDebt = null;
    setState(() {});
  }

  void _selectDebt(coredebt.DebtRecord d) {
    // lock selection until undo
    if (selectedDebt != null && selectedDebt!.id != d.id) {
      _toast('Press Undo to select another supplier');
      return;
    }

    selectedDebt = d;
    supplier = d.supplier;
    fuelType = d.fuelType;

    // reset inputs
    salesCtrl.clear();
    extCtrl.clear();

    setState(() {});
  }

  void _toast(String msg, {bool green = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: green ? Colors.green : Colors.red),
    );
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
          borderSide: const BorderSide(color: Colors.blue),
          borderRadius: BorderRadius.circular(8),
        ),
      );

  Widget _moneyField(String label, TextEditingController c, {required bool enabled}) => SizedBox(
        height: 48,
        child: TextField(
          controller: c,
          enabled: enabled,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsSeparatorInputFormatter()],
          decoration: _input(label),
          style: const TextStyle(color: textPrimary),
          onChanged: (_) => setState(() {}),
        ),
      );

  Widget _dropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return SizedBox(
      height: 48,
      child: DropdownButtonFormField<String>(
        value: value,
        isDense: true,
        isExpanded: true,
        dropdownColor: panelBg,
        decoration: _input(label),
        items: items
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(color: textPrimary)),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  String _fmtDate(DateTime d) => DateFormat('EEE, MMM d').format(d);

  /* ===================== BUILD ===================== */

  @override
  Widget build(BuildContext context) {
    // Part B filter values
    final supplierOptions = <String>{'All', ..._todayDeliveries.map((e) => e.supplier)}.toList()
      ..removeWhere((e) => e.trim().isEmpty);
    final fuelOptions = <String>{'All', ..._todayDeliveries.map((e) => e.fuelType)}.toList();
    final sourceOptions = <String>{'All', ..._todayDeliveries.map((e) => e.source)}.toList();

    final filteredLen = filteredToday.length;

    final maxSales = _availableSalesMoney();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /* ===================== PART A: SETTLEMENT ===================== */
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Settlement',
                    style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 12),

                // top row
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextField(
                          controller: TextEditingController(text: supplier)
                            ..selection = TextSelection.collapsed(offset: supplier.length),
                          onChanged: (v) => supplier = v,
                          decoration: _input('Supplier'),
                          style: const TextStyle(color: textPrimary),
                          enabled: selectedDebt == null, // if debt selected, lock supplier typing
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _dropdown('Fuel', fuelType, fuels, (v) => setState(() => fuelType = v!)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _dropdown('Source', source, sources, (v) {
                        setState(() {
                          source = v!;
                          if (source == 'Sales') extCtrl.clear();
                          if (source == 'External') salesCtrl.clear();
                        });
                      }),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // payment row
                Row(
                  children: [
                    Expanded(
                      child: _moneyField(
                        'Sales Amount (₦)',
                        salesCtrl,
                        enabled: source == 'Sales' || source == 'Sales+External',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _moneyField(
                        'External Amount (₦)',
                        extCtrl,
                        enabled: source == 'External' || source == 'Sales+External',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ✅ Sales available (like delivery)
                if (_usesSalesMoney)
                  Text(
                    _refreshingSales ? 'Sales available: ...' : 'Sales available: ${money.format(maxSales)}',
                    style: const TextStyle(color: textSecondary, fontSize: 12),
                  ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _undo,
                        icon: const Icon(Icons.undo),
                        label: const Text('Undo'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (selectedDebt != null && totalPaid > 0) ? _settle : null,
                        icon: const Icon(Icons.payment),
                        label: const Text('Settle'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // summary (NO "Outstanding" chip as you requested)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _miniSummary('Total Debt', money.format(totalDebtAmount),
                        totalDebtAmount > 0 ? Colors.orange : Colors.green),
                    _miniSummary('Overpaid', money.format(totalCreditRemaining),
                        totalCreditRemaining > 0 ? Colors.greenAccent : Colors.white70),
                  ],
                ),

                const SizedBox(height: 14),

                Text(
                  'Outstanding (${outstandingList.length})',
                  style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: (_loadingCredits)
                      ? const Center(child: CircularProgressIndicator())
                      : outstandingList.isEmpty
                          ? const Center(
                              child: Text('No outstanding items', style: TextStyle(color: textSecondary)),
                            )
                          : ListView.separated(
                              itemCount: outstandingList.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final item = outstandingList[i];

                                final isDebt = item.type == OutstandingType.debt;
                                final isSelected = isDebt && selectedDebt?.id == item.id;

                                return GestureDetector(
                                  onTap: isDebt
                                      ? () {
                                          final d = debts.firstWhere((x) => x.id == item.id);
                                          _selectDebt(d);
                                        }
                                      : null, // credits are just view (delivery consumes them)
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blue.withOpacity(0.15)
                                          : Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: panelBorder),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${item.supplier} • ${item.fuelType}',
                                                style: const TextStyle(
                                                  color: textPrimary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _fmtDate(item.date),
                                              style: const TextStyle(color: textSecondary, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        if (isDebt)
                                          Text(
                                            'DEBT ${money.format(item.amount)}',
                                            style: const TextStyle(
                                              color: Colors.redAccent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          )
                                        else ...[
                                          // NOTE: original credit is not stored in DB (credit reduces as it is consumed)
                                          Text(
                                            'OVERPAID ${money.format(item.amount)}',
                                            style: const TextStyle(
                                              color: Colors.greenAccent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Remaining ${money.format(item.amount)}',
                                            style: const TextStyle(color: textSecondary, fontSize: 12),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 18),

          /* ===================== PART B: TODAY DELIVERY HISTORY ===================== */
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today Delivery History ($filteredLen)',
                  style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 12),

                // filters row
                Row(
                  children: [
                    Expanded(
                      child: _dropdown(
                        'Supplier',
                        filterSupplier,
                        supplierOptions,
                        (v) => setState(() => filterSupplier = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _dropdown(
                        'Fuel',
                        filterFuel,
                        fuelOptions,
                        (v) => setState(() => filterFuel = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _dropdown(
                        'Source',
                        filterSource,
                        sourceOptions,
                        (v) => setState(() => filterSource = v!),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ✅ Removed totals card (as requested)

                Expanded(
                  child: _loadingToday
                      ? const Center(child: CircularProgressIndicator())
                      : filteredToday.isEmpty
                          ? const Center(
                              child: Text('No deliveries for today (with these filters)',
                                  style: TextStyle(color: textSecondary)),
                            )
                          : ListView.builder(
                              itemCount: filteredToday.length,
                              itemBuilder: (_, i) {
                                final r = filteredToday[i];
                                final sTxt = r.salesPaid > 0 ? money.format(r.salesPaid) : '₦0';
                                final eTxt = r.externalPaid > 0 ? money.format(r.externalPaid) : '₦0';
                                final oTxt = r.creditUsed > 0 ? money.format(r.creditUsed) : '₦0';

                                return Card(
                                  color: cardBg,
                                  margin: const EdgeInsets.symmetric(vertical: 5),
                                  child: ListTile(
                                    title: Text('${r.supplier} • ${r.fuelType} • ${r.source}',
                                        style: const TextStyle(color: textPrimary)),
                                    subtitle: Text(
                                      '${commas.format(r.liters.toInt())}L • Cost ${money.format(r.totalCost)}',
                                      style: const TextStyle(color: textSecondary),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('S $sTxt',
                                            style: const TextStyle(color: Colors.orange, fontSize: 12)),
                                        Text('E $eTxt',
                                            style: const TextStyle(color: Colors.cyan, fontSize: 12)),
                                        Text('O $oTxt',
                                            style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Date: $_todayKey',
                    style: const TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniSummary(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  void dispose() {
    salesCtrl.dispose();
    extCtrl.dispose();
    super.dispose();
  }
}
