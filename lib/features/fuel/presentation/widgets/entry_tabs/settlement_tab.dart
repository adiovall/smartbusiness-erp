//lib/features/fuel/presentation/widgets/entry_tabs/settlement_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '/../core/services/service_registry.dart';
import '/../core/models/debt_record.dart' as coredebt;
import '/../core/models/delivery_record.dart' as coredel;
import '/../core/models/settlement_record.dart' as coreset;

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

  coredebt.DebtRecord? selectedDebt;

  // Part B (today delivery history)
  bool _loadingToday = true;
  List<coredel.DeliveryRecord> _todayDeliveries = [];

  String filterSupplier = 'All';
  String filterFuel = 'All';
  String filterSource = 'All';

  final money = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
  final commas = NumberFormat.decimalPattern('en_NG');

  String get _today => DateTime.now().toIso8601String().split('T').first;

  bool get split => source == 'Sales+External';

  double _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;

  double get salesPaid => split ? _num(salesCtrl) : (source == 'Sales' ? _num(salesCtrl) : 0);
  double get externalPaid => split ? _num(extCtrl) : (source == 'External' ? _num(extCtrl) : 0);
  double get totalPaid => salesPaid + externalPaid;

  List<coredebt.DebtRecord> get debts =>
      Services.debt.allDebts.where((d) => !d.settled).toList();

  double get totalDebt => Services.debt.totalDebt;

  List<coredel.DeliveryRecord> get filteredToday {
    return _todayDeliveries.where((d) {
      final okSupplier = filterSupplier == 'All' || d.supplier == filterSupplier;
      final okFuel = filterFuel == 'All' || d.fuelType == filterFuel;
      final okSource = filterSource == 'All' || d.source == filterSource;
      return okSupplier && okFuel && okSource;
    }).toList();
  }

  double get todayLiters => filteredToday.fold(0.0, (s, r) => s + r.liters);
  double get todayCost => filteredToday.fold(0.0, (s, r) => s + r.totalCost);
  double get todayPaid => filteredToday.fold(0.0, (s, r) => s + r.amountPaid);
  double get todaySalesPaid => filteredToday.fold(0.0, (s, r) => s + r.salesPaid);
  double get todayExternalPaid => filteredToday.fold(0.0, (s, r) => s + r.externalPaid);

  @override
  void initState() {
    super.initState();
    _loadTodayDeliveries();
  }

  Future<void> _loadTodayDeliveries() async {
    setState(() => _loadingToday = true);
    final rows = await Services.deliveryRepo.fetchTodaySubmitted();
    if (!mounted) return;
    setState(() {
      _todayDeliveries = rows;
      _loadingToday = false;

      // build defaults for supplier dropdown from data if empty
      if (supplier.isEmpty && debts.isNotEmpty) {
        supplier = debts.first.supplier;
        fuelType = debts.first.fuelType;
      }
    });
  }

  /* ===================== ACTIONS ===================== */

  Future<void> _settle() async {
    if (supplier.trim().isEmpty) {
      _toast('Select supplier');
      return;
    }
    if (totalPaid <= 0) {
      _toast('Enter settlement amount');
      return;
    }

    try {
      // mark settlement draft
      await Services.dayEntry.markDraft(_today, 'Set');

      final coreset.SettlementRecord record = await Services.settlement.settleSplit(
        supplier: supplier.trim(),
        fuelType: fuelType,
        salesPaid: salesPaid,
        externalPaid: externalPaid,
        source: source,
      );

      widget.onSubmitted();

      _undo();

      // refresh today deliveries (credits may have been added)
      await _loadTodayDeliveries();

      if (!mounted) return;
      _toast(
        record.credit > 0
            ? 'Settled. Credit ₦${commas.format(record.credit.toInt())}'
            : 'Settled successfully',
        green: true,
      );

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
      SnackBar(
        content: Text(msg),
        backgroundColor: green ? Colors.green : Colors.red,
      ),
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

  Widget _summaryChip(String label, String value, Color color) {
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
  Widget build(BuildContext context) {
    // Part B filter values
    final supplierOptions = <String>{'All', ..._todayDeliveries.map((e) => e.supplier)}.toList()
      ..removeWhere((e) => e.trim().isEmpty);
    final fuelOptions = <String>{'All', ..._todayDeliveries.map((e) => e.fuelType)}.toList();
    final sourceOptions = <String>{'All', ..._todayDeliveries.map((e) => e.source)}.toList();

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
                const Text('Settlement (Part A)',
                    style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 12),

                // top row
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextField(
                          controller: TextEditingController(text: supplier)..selection = TextSelection.collapsed(offset: supplier.length),
                          onChanged: (v) => supplier = v,
                          decoration: _input('Supplier'),
                          style: const TextStyle(color: textPrimary),
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
                          // clear opposite field when not split
                          if (source == 'Sales') extCtrl.clear();
                          if (source == 'External') salesCtrl.clear();
                        });
                      }),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // payment row (always shows Sales+External like your sketch)
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
                        onPressed: totalPaid > 0 ? _settle : null,
                        icon: const Icon(Icons.payment),
                        label: Text('Settle'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _summaryChip(
                      'Outstanding',
                      money.format(totalDebt),
                      totalDebt > 0 ? Colors.red : Colors.green,
                    ),
                    _summaryChip('Total Debt', money.format(totalDebt), Colors.orange),
                    _summaryChip('Overpaid', money.format(0), Colors.green), // optional
                  ],
                ),

                const SizedBox(height: 14),

                const Text('Debts',
                    style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),

                Expanded(
                  child: debts.isEmpty
                      ? const Center(child: Text('No active debts', style: TextStyle(color: textSecondary)))
                      : ListView.separated(
                          itemCount: debts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final d = debts[i];
                            final selected = selectedDebt?.id == d.id;

                            return GestureDetector(
                              onTap: () => _selectDebt(d),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.blue.withOpacity(0.15)
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: panelBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${d.supplier} • ${d.fuelType}',
                                        style: const TextStyle(
                                            color: textPrimary, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    Text('DEBT ${money.format(d.amount)}',
                                        style: const TextStyle(
                                            color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
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
                const Text('Today Delivery History (Part B)',
                    style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
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

                // totals
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: panelBorder),
                  ),
                  child: Column(
                    children: [
                      _rowKV('Total Liters', '${commas.format(todayLiters.toInt())} L'),
                      _rowKV('Total Cost', money.format(todayCost)),
                      _rowKV('Total Paid', money.format(todayPaid)),
                      _rowKV('Sales Paid', money.format(todaySalesPaid)),
                      _rowKV('External Paid', money.format(todayExternalPaid)),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

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
                                return Card(
                                  color: cardBg,
                                  margin: const EdgeInsets.symmetric(vertical: 5),
                                  child: ListTile(
                                    title: Text('${r.supplier} • ${r.fuelType} • ${r.source}',
                                        style: const TextStyle(color: textPrimary)),
                                    subtitle: Text(
                                      '${commas.format(r.liters.toInt())}L • Cost ${money.format(r.totalCost)} • Paid ${money.format(r.amountPaid)}',
                                      style: const TextStyle(color: textSecondary),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('S ${money.format(r.salesPaid)}',
                                            style: const TextStyle(color: Colors.orange, fontSize: 12)),
                                        Text('E ${money.format(r.externalPaid)}',
                                            style: const TextStyle(color: Colors.cyan, fontSize: 12)),
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
                    'Date: $_today',
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

  Widget _rowKV(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: textSecondary)),
          Text(v, style: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    salesCtrl.dispose();
    extCtrl.dispose();
    super.dispose();
  }
}
