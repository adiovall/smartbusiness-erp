// lib/features/fuel/presentation/screens/fuel_admin_final.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';

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
import '../../../auth/presentation/widgets/link_cloud_dialog.dart';
import '../../../../core/services/sync_service.dart' show CloudSessionRequiredException;
import '../../../../core/services/service_registry.dart';
import '../../../../core/models/day_entry.dart' as de;
import '../../../../core/services/day_entry_service.dart' show DaySentAlreadyException;

import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/update_service.dart';


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
      // listen to tank updates (for tank widget)
      Services.tank.addListener(_onTankChanged);
      Services.sale.addListener(_onDraftsChanged);
      Services.delivery.addListener(_onDraftsChanged);
      Services.expense.addListener(_onDraftsChanged);
      Services.debt.addListener(_onDraftsChanged);
      Services.tankDip.addListener(_onDraftsChanged);
    
      _initializeData();
    
      Future.microtask(() async {
        // Load today's totals
        final salesTotal = await Services.saleRepo.getTodayTotalAmount();
        final expenseTotal = Services.expense.todayExpenseTotal;
    
        await _loadWeeklyFromDayEntryCache();
    
        if (!mounted) return;
        setState(() {
          todaysSales = salesTotal;
          todaysExpense = expenseTotal;
          _loading = false;
        });
      });
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
    }
  }


  Future<void> _initializeData() async {
    await Services.init();

    await Services.dayEntry.getOrCreate(_businessDateKey(_now));

    todaysSales = await Services.sale.todayTotalAmount(includeDraft: false);
    todaysExpense = Services.expense.todayFinalizedTotal;
    todaysDelivery = await Services.delivery.todayTotalAmount(); 
    
    todaySaleCount = await Services.saleRepo.countTodaySubmitted();
    todayDeliveryCount = await Services.deliveryRepo.countTodaySubmitted();
    todayExpenseCount = await Services.expenseRepo.countTodaySubmitted();
    final todayAlreadySent = Services.dayEntry.isDayAlreadySent(_businessDateKey(_now));
    todaySettlementCount = await Services.settlement.todaySubmittedCount(_businessDateKey(_now), todayAlreadySent);

    final dipDraftCount = await Services.tankDip
    .countForBusinessDate(_businessDateKey(_now));
    _hasTankDipDrafts = dipDraftCount > 0;

    todayTankDipCount = await Services.tankDip
        .countSubmittedForBusinessDate(_businessDateKey(_now));
    

    await _loadWeeklyFromDayEntryCache();

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
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
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
            child: const Text('Download'),
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
          final title = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (logoPath != null) ...[
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
              ),
              const SizedBox(height: 16),
              _buildDailySubmitCard(),
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
