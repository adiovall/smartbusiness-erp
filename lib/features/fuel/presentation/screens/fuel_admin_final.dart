// lib/features/fuel/presentation/screens/fuel_admin_final.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

import 'analytics_screen.dart';
import 'settings_screen.dart';
import '../widgets/entry_tabs/sale_tab.dart';
import '../widgets/entry_tabs/delivery_tab.dart';
import '../widgets/entry_tabs/expense_tab.dart';
import '../widgets/entry_tabs/settlement_tab.dart';
import '../widgets/entry_tabs/external_payments_tab.dart';
import '../widgets/tank_levels_perfect.dart';
import '../widgets/weekly_summary_perfect.dart';
import '../widgets/entry_tabs/tank_dip_tab.dart';
import '../../../auth/presentation/screens/manage_staff_screen.dart';
import '../../../auth/presentation/widgets/cloud_sign_in_dialog.dart';
import '../../../../core/services/sync_service.dart' show CloudSessionRequiredException;
import '../../../../core/services/service_registry.dart';
import '../../../../core/models/day_entry.dart' as de;
import '../../../../core/services/day_entry_service.dart' show DaySentAlreadyException;

import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/update_service.dart';
import '../../../../core/services/subscription_service.dart';



class FuelAdminFinal extends StatefulWidget {
  const FuelAdminFinal({super.key});

  @override
  State<FuelAdminFinal> createState() => _FuelAdminFinalState();
}

class _FuelAdminFinalState extends State<FuelAdminFinal>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  final DateTime _now = DateTime.now();

  double todaysSales = 0.0;
  double todaysExpense = 0.0;
  double todaysDelivery = 0.0;

  final Map<String, Map<String, de.DayEntryStatus>> weeklyStatus = {};
  final Map<String, bool> daySentStatus = {};
  final Map<String, String?> sentByMap = {};


  int todaySettlementCount = 0;
  int todaySaleCount = 0;
  int todayDeliveryCount = 0;
  int todayTankDipCount = 0;
  int todayExpenseCount = 0;

  bool settlementInProgress = false;
  bool _hasTankDipDrafts = false;

  bool _loading = true;
  UpdateInfo? _updateAvailable;

  // ✅ Needed for horizontal scroll when screen is compressed
  final ScrollController _mainHScroll = ScrollController();
  final ScrollController _summaryHScroll = ScrollController();

  // ✅ format with commas
  final NumberFormat _moneyFmt = NumberFormat.decimalPattern();

  String _money(num v) => _moneyFmt.format(v.round());
  

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 6, vsync: this);

    Services.update.checkForUpdate().then((info) {
      if (mounted && info != null) setState(() => _updateAvailable = info);
    });
    Services.tank.addListener(_onTankChanged);
    Services.sale.addListener(_onDraftsChanged);
    Services.delivery.addListener(_onDraftsChanged);
    Services.expense.addListener(_onDraftsChanged);
    Services.debt.addListener(_onDraftsChanged);
    Services.tankDip.addListener(_onDraftsChanged);

    _initializeData();
  }
    
    void _onTankChanged() {
      if (mounted) setState(() {});
    }
    
    // ✅ NEW: proper class-level method, not a local function inside initState().
    // This is what makes it reachable from dispose() too.
    void _onDraftsChanged() {
      if (mounted) setState(() {});
    }
    
    @override
    void dispose() {
      Services.tank.removeListener(_onTankChanged);
      Services.sale.removeListener(_onDraftsChanged);
      Services.delivery.removeListener(_onDraftsChanged);
      Services.expense.removeListener(_onDraftsChanged);
      Services.debt.removeListener(_onDraftsChanged);
      Services.tankDip.removeListener(_onDraftsChanged);
    
      tabController.dispose();
      _mainHScroll.dispose();
      _summaryHScroll.dispose();
      super.dispose();
    }

  // =====================
  // DATE HELPERS
  // =====================

  String _businessDateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _uiDayKey(DateTime d) => DateFormat('EEE dd').format(d);

  DateTime _weekStart(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

  // =====================
  // WEEKLY STATUS (DB → UI)
  // =====================

  Future<void> _loadWeeklyFromDayEntryCache() async {
    final start = _weekStart(_now);
    final sentByMap = <String, String?>{};

    // Force reload from DB to ensure cache is fresh
    await Services.dayEntry.loadWeek(start);
    weeklyStatus.clear();
    daySentStatus.clear();
    

    for (int i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      final uiKey = _uiDayKey(day);
      final dbKey = _businessDateKey(day);

      final entry = Services.dayEntry.getFromCache(dbKey);

      weeklyStatus[uiKey] = {
        'Sale': entry?.sale ?? de.DayEntryStatus.none,
        'Del': entry?.delivery ?? de.DayEntryStatus.none,
        'Exp': entry?.expense ?? de.DayEntryStatus.none,
        'Set': entry?.settlement ?? de.DayEntryStatus.none,
        'Dip': entry?.tankDip ?? de.DayEntryStatus.none,
      };

      daySentStatus[uiKey] = entry?.submittedAt != null;

      sentByMap[uiKey] = entry?.sentByEmail != null
          ? '${entry!.sentByEmail} (${entry.sentByRole == 'owner' ? 'Admin' : 'Manager'})'
          : null;
    }
  }


  Future<void> _initializeData() async {
    try {
      await Services.init();

      try {
        await Services.configSync.pullAll().timeout(const Duration(seconds: 8));
      } catch (_) {}

      await Services.dayEntry.getOrCreate(_businessDateKey(_now));

      todaysSales = await Services.sale.todayTotalAmount(includeDraft: false);
      todaysExpense = Services.expense.todayFinalizedTotal;
      todaysDelivery = await Services.delivery.todayTotalAmount();

      todaySaleCount = await Services.saleRepo.countTodaySubmitted();
      todayDeliveryCount = await Services.deliveryRepo.countTodaySubmitted();
      todayExpenseCount = await Services.expenseRepo.countTodaySubmitted();
      final todayAlreadySent = Services.dayEntry.isDayAlreadySent(_businessDateKey(_now));
      todaySettlementCount = await Services.settlement.todaySubmittedCount(_businessDateKey(_now), todayAlreadySent);

      final dipDraftCount = await Services.tankDip.countForBusinessDate(_businessDateKey(_now));
      _hasTankDipDrafts = dipDraftCount > 0;

      todayTankDipCount = await Services.tankDip.countSubmittedForBusinessDate(_businessDateKey(_now));

      await _loadWeeklyFromDayEntryCache();
    } catch (e) {
      debugPrint('_initializeData failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load app data: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  // =====================
  // MARK TAB AS DRAFT
  // =====================

  Future<void> _markDraft(String type) async {
    final date = _businessDateKey(_now);
    await Services.dayEntry.markSubmitted(date, type);
    await _loadWeeklyFromDayEntryCache();
    if (mounted) setState(() {});
  }


  // =====================
  // SEND DATA FLOW
  // =====================

  // Replace _confirmSendData() with this version. When today is already
  // sent but has new submitted activity, instead of just a message, it
  // offers to open the edit-date flow directly so the person can retag
  // that activity to an earlier, unsent business date right away.

  Future<void> _confirmSendData() async {
    final unsent = await Services.dayEntry.fetchUnsentDates();

    if (unsent.isNotEmpty) {
      await _showDatePickerDialog(unsent);
      return;
    }

    final todayDbKey = _businessDateKey(_now);
    final todayEntry = await Services.dayEntry.getOrCreate(todayDbKey);
    final todayAlreadySent = todayEntry.submittedAt != null;

    final hasAnySubmittedToday = [
      todayEntry.sale,
      todayEntry.delivery,
      todayEntry.expense,
      todayEntry.settlement,
    ].any((s) => s == de.DayEntryStatus.submitted);

    if (todayAlreadySent && hasAnySubmittedToday) {
      final wantsToRetag = await showDialog<bool>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: const Color(0xFF020617),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Data Already Sent",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Today was already sent and can't be sent again. "
                  "If this new activity actually belongs to an earlier day "
                  "that hasn't been sent yet, you can move it there now. "
                  "Otherwise, leave it — it will be picked up once tomorrow "
                  "becomes the new business day.",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Leave it for tomorrow'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Move to another date'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      if (wantsToRetag == true) {
        final newDate = await _showEditDateDialog(todayDbKey);
        if (newDate == null) return; // they cancelled the picker

        try {
          await Services.dayEntry.correctBusinessDate(oldDate: todayDbKey, newDate: newDate);
        } on DaySentAlreadyException {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$newDate has already been sent. Cannot move data there.')),
          );
          return;
        }

        await _initializeData();
        await _loadWeeklyFromDayEntryCache();
        if (!mounted) return;
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Moved to $newDate. Open Send Data again to send it.')),
        );
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nothing to send')),
    );
  }


  Future<void> _showDatePickerDialog(List<de.DayEntry> unsent) async {
    final picked = await showDialog<de.DayEntry>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF020617),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white, width: 1), // ← white border
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Business Date',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400, minWidth: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: unsent.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0xFF1f2937)),
                  itemBuilder: (_, i) {
                    final entry = unsent[i];
                    return ListTile(
                      title: Text(entry.date, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        _sectionsSummary(entry),
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                      onTap: () => Navigator.pop(context, entry),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (picked == null) return;

    await _showSendConfirmDialog(picked, unsent);
  }

  Future<void> _exportCsv() async {
    final csv = await Services.csvExport.exportAllAsCsv();

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Historical Data',
      fileName: 'fuelflow-historical-${DateTime.now().toIso8601String().split("T").first}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (path == null) return;

    await File(path).writeAsString(csv);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Historical data exported'), backgroundColor: Colors.green),
    );
  }

  String _sectionsSummary(de.DayEntry entry) {
    final parts = <String>[];
    if (entry.sale == de.DayEntryStatus.submitted) parts.add('Sale');
    if (entry.delivery == de.DayEntryStatus.submitted) parts.add('Delivery');
    if (entry.tankDip == de.DayEntryStatus.submitted) parts.add('Tank Dip');
    if (entry.expense == de.DayEntryStatus.submitted) parts.add('Expense');
    if (entry.settlement == de.DayEntryStatus.submitted) parts.add('Settlement');
    return parts.isEmpty ? 'No sections submitted' : parts.join(' • ');
  }

  Future<void> _showSendConfirmDialog(
    de.DayEntry entry,
    List<de.DayEntry> unsentListForBackNav,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF020617),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white, width: 1), // ← white border
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Send This Data?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
                _row('Sales', entry.sale),
                _row('Delivery', entry.delivery),
                _row('Tank Dip', entry.tankDip),
                _row('Expense', entry.expense),
                _row('Settlement', entry.settlement),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Business Date: ', style: TextStyle(color: Colors.grey)),
                  Text(entry.date, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => Navigator.pop(context, 'edit'),
                    child: const Icon(Icons.edit, size: 16, color: Colors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'delete'),
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    child: const Text('Delete'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'cancel'),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('Send'),
                    onPressed: () => Navigator.pop(context, 'send'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (action == 'cancel' || action == null) {
      // ✅ Cancel goes BACK to the date picker list, not all the way out —
      // unless there's nothing left to pick (handled by re-fetching fresh).
      final freshUnsent = await Services.dayEntry.fetchUnsentDates();
      if (freshUnsent.isEmpty) {
        final hasUnsynced = await Services.outboxRepo.hasUnsynced();
          if (hasUnsynced) {
            await _pushToCloud();
            return;
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nothing to send')),
          );
        return;
      }
      await _showDatePickerDialog(freshUnsent);
      return;
    }

    if (action == 'edit') {
      final newDate = await _showEditDateDialog(entry.date);
      if (newDate == null) {
        // they cancelled the edit — go back to the SAME confirm dialog
        await _showSendConfirmDialog(entry, unsentListForBackNav);
        return;
      }

      try {
        await Services.dayEntry.correctBusinessDate(oldDate: entry.date, newDate: newDate);
      } on DaySentAlreadyException {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$newDate has already been sent. Cannot move data there.')),
        );
        // go back to picker fresh
        final freshUnsent = await Services.dayEntry.fetchUnsentDates();
        if (freshUnsent.isNotEmpty) await _showDatePickerDialog(freshUnsent);
        return;
      }

      // re-fetch the corrected entry (now living under newDate) and show
      // the confirm dialog again with the updated date.
      final updatedEntry = await Services.dayEntry.getOrCreate(newDate);
      await _initializeData();
      await _loadWeeklyFromDayEntryCache();
      if (mounted) setState(() {});

      final freshUnsent = await Services.dayEntry.fetchUnsentDates();
      await _showSendConfirmDialog(updatedEntry, freshUnsent);
      return;
    }

    if (action == 'send') {
      await _sendData(entry.date);
    }

    if (action == 'delete') {
      final confirmed = await _confirmDeleteEntry(entry);
      if (confirmed != true) {
        // they backed out — return to the same confirm dialog
        await _showSendConfirmDialog(entry, unsentListForBackNav);
        return;
      }

      await _deleteEntryData(entry.date);

      if (!mounted) return;
      final freshUnsent = await Services.dayEntry.fetchUnsentDates();
      if (freshUnsent.isNotEmpty) {
        await _showDatePickerDialog(freshUnsent);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to send')),
        );
      }
      return;
    }
  }

  Future<bool?> _confirmDeleteEntry(de.DayEntry entry) {
    return showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF020617),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delete This Data?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                'This permanently deletes all Sale, Delivery, Tank Dip, Expense, and '
                'Settlement entries recorded for ${entry.date}. This cannot be undone.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete Permanently'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteEntryData(String businessDate) async {
    try {
      await Services.settlement.deleteAllForBusinessDate(businessDate);
      await Services.debt.deleteAllForBusinessDate(businessDate);
      await Services.delivery.deleteAllForBusinessDate(businessDate);
      await Services.sale.deleteAllForBusinessDate(businessDate);
      await Services.expense.deleteAllForBusinessDate(businessDate);
      await Services.tankDip.deleteAllForBusinessDate(businessDate);
      await Services.dayEntry.deleteEntry(businessDate);

      await _initializeData();
      await _loadWeeklyFromDayEntryCache();
      if (!mounted) return;
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted all data for $businessDate')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<String?> _showEditDateDialog(String currentDate) async {
    DateTime initial = DateTime.tryParse(currentDate) ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.orange,
              surface: Color(0xFF020617),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return null;
    return DateFormat('yyyy-MM-dd').format(picked);
  }

  Widget _row(String label, de.DayEntryStatus status) {
    final color = status == de.DayEntryStatus.draft
        ? Colors.amber
        : status == de.DayEntryStatus.submitted
            ? Colors.green
            : Colors.grey;

    final icon = status == de.DayEntryStatus.none
        ? Icons.circle_outlined
        : Icons.check_circle;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white))),
          Icon(icon, color: color, size: 16),
        ],
      ),
    );
  }

  Future<void> _showDaySummaryDialog() async {
    final date = _businessDateKey(_now);


    final sales = await Services.sale.allForBusinessDate(date);
    final deliveries = await Services.delivery.allForBusinessDate(date);
    final tankDips = await Services.tankDip.allForBusinessDateForOutbox(date);
    final expenses = await Services.expense.allForBusinessDate(date);
    final settlements = await Services.settlement.allForBusinessDate(date);
    final debts = Services.debt.allForBusinessDate(date);
    final tanks = Services.tank.allTanks;

    Widget row(String left, String right, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(left, style: const TextStyle(color: Colors.white, fontSize: 12))),
              Text(right, style: TextStyle(color: color ?? Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        );

    Widget section(String title, List<dynamic> items, Widget Function(dynamic) builder) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$title (${items.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            if (items.isEmpty)
              const Text('No entries', style: TextStyle(color: Colors.white38, fontSize: 12))
            else
              ...items.map(builder),
          ],
        ),
      );
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF0f172a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF1f2937))),
        child: SizedBox(
          width: 480,
          height: 560,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Today — $date', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const Divider(color: Color(0xFF1f2937)),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        section('Sales', sales, (s) => row(
                              'Pump ${s.pumpNo} • ${s.fuelType} • ${(s.liters as double).toStringAsFixed(0)}L',
                              _money(s.totalAmount as double), color: Colors.greenAccent)),
                        section('Deliveries', deliveries, (d) => row(
                              '${d.supplier} • ${d.fuelType} • ${(d.liters as double).toStringAsFixed(0)}L',
                              _money(d.totalCost as double), color: Colors.orange)),
                        section('Tank Dips', tankDips, (t) => row(
                              '${t.fuelType} • ${(t.openingLevel as double).toStringAsFixed(0)} → ${(t.closingLevel as double).toStringAsFixed(0)}',
                              '${(t.variance as double) >= 0 ? '+' : ''}${(t.variance as double).toStringAsFixed(0)} L',
                              color: (t.variance as double) >= 0 ? Colors.greenAccent : Colors.redAccent)),
                        section('Expenses', expenses, (e) => row(e.category as String, _money(e.amount as double), color: Colors.redAccent)),
                        section('Settlements', settlements, (s) => row('${s.supplier} • ${s.fuelType}', _money(s.paidAmount as double), color: Colors.cyan)),
                        section('Debts', debts, (d) => row('${d.supplier} • ${d.fuelType}', _money(d.amount as double),
                            color: (d.settled as bool) ? Colors.greenAccent : Colors.redAccent)),
                        section('Current Tank Levels', tanks, (t) => row(t.fuelType as String,
                            '${t.currentLevel.toStringAsFixed(0)} / ${t.capacity.toStringAsFixed(0)} L (${t.percentage.toStringAsFixed(0)}%)', color: Colors.cyan)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _downloadDaySummary() async {
    final date = _businessDateKey(_now);

    final sales = await Services.sale.allForBusinessDate(date);
    final deliveries = await Services.delivery.allForBusinessDate(date);
    final tankDips = await Services.tankDip.allForBusinessDateForOutbox(date);
    final expenses = await Services.expense.allForBusinessDate(date);
    final settlements = await Services.settlement.allForBusinessDate(date);
    final debts = Services.debt.allForBusinessDate(date);
    final tanks = Services.tank.allTanks;

    final rows = <List<dynamic>>[];
    rows.add(['FuelFlow ERP — Day Summary']);
    rows.add(['Business Date', date]);
    rows.add([]);

    rows.add(['SALES']);
    rows.add(['Pump', 'Fuel', 'Opening', 'Closing', 'Liters', 'Unit Price', 'Amount']);
    for (final s in sales) {
      rows.add([s.pumpNo, s.fuelType, s.opening, s.closing, s.liters, s.unitPrice, s.totalAmount]);
    }
    rows.add([]);

    rows.add(['DELIVERIES']);
    rows.add(['Supplier', 'Fuel', 'Liters', 'Total Cost', 'Debt', 'Credit']);
    for (final d in deliveries) {
      rows.add([d.supplier, d.fuelType, d.liters, d.totalCost, d.debt, d.credit]);
    }
    rows.add([]);

    rows.add(['TANK DIPS']);
    rows.add(['Fuel', 'Opening', 'Closing', 'Variance', 'Notes']);
    for (final t in tankDips) {
      rows.add([t.fuelType, t.openingLevel, t.closingLevel, t.variance, t.notes ?? '']);
    }
    rows.add([]);

    rows.add(['EXPENSES']);
    rows.add(['Category', 'Amount', 'Comment']);
    for (final e in expenses) {
      rows.add([e.category, e.amount, e.comment]);
    }
    rows.add([]);

    rows.add(['SETTLEMENTS']);
    rows.add(['Supplier', 'Fuel', 'Paid Amount', 'Remaining Debt', 'Credit']);
    for (final s in settlements) {
      rows.add([s.supplier, s.fuelType, s.paidAmount, s.remainingDebt, s.credit]);
    }
    rows.add([]);

    rows.add(['DEBTS']);
    rows.add(['Supplier', 'Fuel', 'Amount', 'Settled']);
    for (final d in debts) {
      rows.add([d.supplier, d.fuelType, d.amount, d.settled ? 'Yes' : 'No']);
    }
    rows.add([]);

    rows.add(['CURRENT TANK LEVELS']);
    rows.add(['Fuel', 'Current', 'Capacity', 'Percentage']);
    for (final t in tanks) {
      rows.add([t.fuelType, t.currentLevel, t.capacity, '${t.percentage.toStringAsFixed(0)}%']);
    }

    final csv = const ListToCsvConverter().convert(rows);

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Day Summary',
      fileName: 'day-summary-$date.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (path == null) return;

    await File(path).writeAsString(csv);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to $path'), backgroundColor: Colors.green),
    );
  }

  Future<void> _sendData(String businessDate) async {
    try {
      await Services.dayEntry.submitDay(
        businessDate: businessDate,
        submittedAt: DateTime.now(),
      );
    } on DaySentAlreadyException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This business date has already been sent.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await Services.outbox.buildAndArchive(businessDate);

    // Local submission is complete at this point regardless of what
    // happens next — the day is archived and safely staged in the
    // outbox. Cloud push below is best-effort and retryable; a failure
    // here never reverses or blocks the local send.
    await _pushToCloud();

    await _initializeData();
    await _loadWeeklyFromDayEntryCache();

    if (!mounted) return;
    setState(() {});
  }

  /// Attempts to push any unsynced outbox records to Supabase. Prompts
  /// for a one-time cloud re-sign-in only if the session is missing —
  /// never blocks the local send that already completed above.
  Future<void> _pushToCloud() async {
      final sub = await Services.subscription.checkActive();
      if (sub != null && !sub.isActive) {
        if (!mounted) return;
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF0f172a),
            title: const Text('Subscription Expired', style: TextStyle(color: Colors.white)),
            content: const Text(
              "This station's Pro plan has expired. Data is saved locally, "
              "but cloud sync and Analytics won't update until renewed. "
              "Contact your provider to renew.",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      try {
      final result = await Services.sync.syncAll();
      if (!mounted) return;

      if (result.hasFailures) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Data saved locally, but ${result.recordsFailed} day(s) '
              'failed to reach the cloud. Will retry on next Send Data.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data sent and synced to the cloud'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on CloudSessionRequiredException {
      if (!mounted) return;
      final signedIn = await showDialog<bool>(
        context: context,
        builder: (_) => const CloudSignInDialog(),
      );

      if (signedIn == true) {
        await _pushToCloud(); // retry once now that a session exists
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data saved locally. Sign in to the cloud next '
                'time to sync it.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data saved locally, but cloud sync failed: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
  

  

  void _addSale(double v) => setState(() => todaysSales += v);
  void _addExpense(double v) => setState(() => todaysExpense += v);
  void _addDelivery(double v) => setState(() => todaysDelivery += v);

  bool get isTodaySubmitted {
    final todayDbKey = _businessDateKey(_now);
    return Services.dayEntry.isDayAlreadySent(todayDbKey);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0b1220),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // SIDEBAR
          Container(
            width: 70,
            color: const Color(0xFF020617),
            child: Column(
              children: [
                const SizedBox(height: 20),
                  _sideIcon(Icons.local_gas_station, true, null, 'Fuel'),
                  _sideIcon(Icons.store_mall_directory, false, null, 'Store'),
                  _sideIcon(Icons.water_drop, false, null, 'Water'),
                  if (Services.auth.isOwner)
                    _sideIcon(Icons.analytics, false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AnalyticsScreen(onBack: () => Navigator.pop(context)),
                        ),
                      );
                    },'Analytics'),
                  if (Services.auth.isOwner)
                    _sideIcon(Icons.badge, false, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ManageStaffScreen(onBack: () => Navigator.pop(context)),
                        ),
                      );
                    }, 'Manage Staff'),
                  const Spacer(),
                  _sideIcon(Icons.settings, false, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(onBack: () => Navigator.pop(context))));
                  },'Settings'),
                  _sideIcon(Icons.logout, false, () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFF0f172a),
                        title: const Text('Sign out?', style: TextStyle(color: Colors.white)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out')),
                        ],
                      ),
                    );
                    if (confirm == true) Services.auth.logout();
                  }, 'Sign Out'),
                  const SizedBox(height: 24),
              ],
            ),
          ),

          // MAIN
          Expanded(
            child: Column(
              children: [
                if (_updateAvailable != null) _buildUpdateBanner(),
                _buildTopBarResponsive(),
                _buildSummaryCardsResponsive(),
                Expanded(child: _buildMainBodyResponsive()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================
  // TOP BAR (Responsive)
  // =====================

  Widget _buildUpdateBanner() {
    final info = _updateAvailable!;
    return Container(
      color: Colors.green.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.system_update, color: Colors.greenAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Update available: v${info.version}',
                style: const TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => launchUrl(Uri.parse(info.downloadUrl), mode: LaunchMode.externalApplication),
            child: const Text('Update'),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            onPressed: () => setState(() => _updateAvailable = null),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarResponsive() {
    return LayoutBuilder(
      builder: (context, c) {
        final isTight = c.maxWidth < 900;

        final logoPath = Services.appSettings.logoPath;
          final hasValidLogo = logoPath != null && File(logoPath).existsSync() && File(logoPath).lengthSync() > 0;
          final title = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasValidLogo) ...[
                CircleAvatar(radius: 18, backgroundImage: FileImage(File(logoPath))),
                const SizedBox(width: 10),
              ],
              Text(
                Services.appSettings.stationName,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          );

        final currentUser = Services.auth.currentUser;
        final roleLabel = currentUser?.isOwner == true ? 'Admin' : 'Manager';
        final displayName = (currentUser?.name?.isNotEmpty ?? false)
            ? currentUser!.name!
            : (currentUser?.email ?? '');
        final welcome = Text('Welcome $displayName — $roleLabel',
            style: const TextStyle(color: Colors.white70));

        final date = Text(
          DateFormat('EEEE, MMM d, yyyy').format(_now),
          style: const TextStyle(color: Colors.white60),
        );

        final sendBtn = ElevatedButton.icon(
          onPressed: _confirmSendData,
          icon: const Icon(Icons.send, size: 18),
          label: const Text('Send Data'),
        );

        if (!isTight) {
          return Container(
            color: const Color(0xFF0f172a),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              children: [
                title,
                const SizedBox(width: 20),
                const SizedBox(width: 12),
                if (Services.auth.isOwner) _buildProBadge(),
                welcome,
                const Spacer(),
                date,
                const SizedBox(width: 20),
                sendBtn,
              ],
            ),
          );
        }

        // tight width -> stack into 2 rows (no overflow)
        return Container(
          color: const Color(0xFF0f172a),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: title)),
                  const SizedBox(width: 12),
                  welcome,
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: date),
                  sendBtn,
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProBadge() {
    final sub = Services.subscription.cached;
    final active = sub?.isActive ?? true; // benefit of the doubt until first check completes
    final isTrial = sub?.plan == 'trial';

    final badgeColor = !active
        ? Colors.redAccent
        : isTrial
            ? Colors.cyan
            : Colors.amber;

    final badgeLabel = !active ? 'EXPIRED' : (isTrial ? 'TRIAL' : 'PRO');

    return InkWell(
      onTap: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF0f172a),
          title: Text(
            !active ? 'Plan Expired' : (isTrial ? 'Free Trial' : 'Pro Plan'),
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            _subscriptionMessage(sub, active, isTrial),
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: badgeColor.withOpacity(0.4)),
        ),
        child: Text(badgeLabel,
            style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11)),
      ),
    );
  }

  String _subscriptionMessage(SubscriptionStatus? sub, bool active, bool isTrial) {
    if (sub == null) return 'Checking...';

    final dateStr = DateFormat('MMM d, yyyy').format(sub.expiresAt);

    if (!active) {
      return "${sub.plan.toUpperCase()} — expired on $dateStr. Contact your provider to renew.";
    }

    if (isTrial) {
      final daysLeft = sub.expiresAt.difference(DateTime.now()).inDays;
      final dayWord = daysLeft == 1 ? 'day' : 'days';
      final daysLine = daysLeft <= 0
          ? "Last day of your free trial — expires today ($dateStr)."
          : "$daysLeft $dayWord left in your free trial (expires $dateStr).";
      return "$daysLine Contact your provider to upgrade to Pro before it expires.";
    }

    return "PRO — active until $dateStr";
  }

  // =====================
  // SUMMARY CARDS (Responsive)
  // =====================

  Widget _buildSummaryCardsResponsive() {
    const minWidth = 900.0;

    return Container(
      color: const Color(0xFF111827),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: LayoutBuilder(
        builder: (context, c) {
          final isWide = c.maxWidth >= minWidth;

          final cardsRow = Row(
            children: [
              Expanded(child: _summaryCard('Today\'s Sales', todaysSales, Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard('Today\'s Expense', todaysExpense, Colors.red)),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard('Today\'s Delivery', todaysDelivery, Colors.orange)),
            ],
          );

          if (isWide) return cardsRow;

          return Scrollbar(
            controller: _summaryHScroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _summaryHScroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: minWidth, child: cardsRow),
            ),
          );
        },
      ),
    );
  }

  // =====================
  // MAIN BODY (Responsive)
  // =====================

  Widget _buildMainBodyResponsive() {
    const minBodyWidth = 1280.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= minBodyWidth;

        if (isWide) return _buildMainBodyRow();

        return Scrollbar(
          controller: _mainHScroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _mainHScroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: minBodyWidth,
              child: _buildMainBodyRow(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainBodyRow() {
    return Row(
      children: [
        // LEFT: ENTRY TABS
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Container(
                height: 50,
                color: const Color(0xFF1e293b),
                child: TabBar(
                  controller: tabController,
                  labelColor: Colors.green,
                  tabs: [
                    _tabWithDot('Sale', Services.sale.todayDrafts.isNotEmpty),
                    _tabWithDot('Delivery', Services.delivery.todayDrafts.isNotEmpty),
                    _tabWithDot('Tank Dip', Services.tankDip.todayDrafts.isNotEmpty),
                    _tabWithDot('Expense', Services.expense.todayDrafts.isNotEmpty),
                    _tabWithDot('Settlement', Services.debt.allDebts.any((d) => !d.settled)),
                    const Tab(text: 'External'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: tabController,
                  children: [
                    SaleTab(
                      onSaleRecorded: (total) async{
                        await _initializeData();
                        _markDraft('Sale');
                      },
                      onDraftMarked: () => _markDraft('Sale'),
                    ),
                    DeliveryTab(                        
                      onSubmitted: () async {
                        await Services.dayEntry.markSubmitted(_businessDateKey(_now), 'Del');
                        await _initializeData();
                        await _loadWeeklyFromDayEntryCache();
                        if (mounted) setState(() {});
                      },
                      onDeliveryRecorded: (amount) {
                        setState(() => todaysDelivery += amount);
                      },
                    ),

                    TankDipTab(
                      onSubmitted: () async {
                        await Services.dayEntry.markSubmitted(_businessDateKey(_now), 'TankDip'); // ← ADD
                        await _initializeData();
                        await _loadWeeklyFromDayEntryCache();
                        if (mounted) setState(() {});
                      },
                    ),

                    ExpenseTab(  
                      onSubmitted: () async {
                        await Services.dayEntry.markSubmitted(_businessDateKey(_now), 'Exp');
                        await _initializeData();
                        await _loadWeeklyFromDayEntryCache();
                        if (mounted) setState(() {});
                      },
                    ),

                    SettlementTab(
                      onSubmitted: () async {
                        await Services.dayEntry.markSubmitted(_businessDateKey(_now), 'Set');
                        await _initializeData();
                        await _loadWeeklyFromDayEntryCache();
                        if (mounted) setState(() {});
                      },
                    ),
                    const ExternalPaymentsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // MIDDLE: WEEKLY SUMMARY
        Expanded(
          flex: 1,
          child: Column(
            children: [
              WeeklySummaryPerfect(
                weeklyStatus: weeklyStatus,
                daySentStatus: daySentStatus,
                sentByMap: sentByMap,
              ),
              const SizedBox(height: 16),
              _buildDailySubmitCard(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Tooltip(
                    message: 'View',
                    child: OutlinedButton(
                      onPressed: () => _showDaySummaryDialog(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.cyan,
                        side: const BorderSide(color: Colors.cyan),
                        padding: const EdgeInsets.all(10),
                        shape: const CircleBorder(),
                      ),
                      child: const Icon(Icons.visibility, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: 'Download',
                    child: OutlinedButton(
                      onPressed: () => _downloadDaySummary(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.all(10),
                        shape: const CircleBorder(),
                      ),
                      child: const Icon(Icons.download, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // RIGHT: TANK LEVELS
        const Expanded(
          flex: 2,
          child: TankLevelsPerfect(),
        ),
      ],
    );
  }

  Widget _tabWithDot(String label, bool hasDraft) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(  
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
        if (hasDraft) ...[
          const SizedBox(width: 4),
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Colors.amber,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    ),
  );
}

  // =====================
  // SUMMARY CARD
  // =====================

  Widget _summaryCard(String title, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            '₦${_money(value)}', // ✅ comma formatted
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _sideIcon(IconData icon, [bool active = false, VoidCallback? onTap, String? tooltip]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Tooltip(
        message: tooltip ?? '',
        child: _HoverIcon(icon: icon, active: active, onTap: onTap),
      ),
    );
  }

  Widget _buildDailySubmitCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0f172a),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1f2937)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Submit',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 10),
          _submitCountRow('Sale', todaySaleCount),
          _submitCountRow('Delivery', todayDeliveryCount),
          _submitCountRow('Tank Dip', todayTankDipCount),
          _submitCountRow('Expense', todayExpenseCount),
          _submitCountRow('Settlement', todaySettlementCount),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _submitCountRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(
            '$count',
            style: TextStyle(
              color: count > 0 ? Colors.greenAccent : Colors.white38,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

}

class _HoverIcon extends StatefulWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;
  const _HoverIcon({required this.icon, required this.active, this.onTap});

  @override
  State<_HoverIcon> createState() => _HoverIconState();
}

class _HoverIconState extends State<_HoverIcon> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? Colors.green
        : (_hovering ? Colors.green : Colors.grey);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Icon(widget.icon, size: 28, color: color),
      ),
    );
  }
}
