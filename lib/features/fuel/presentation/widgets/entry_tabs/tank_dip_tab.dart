// lib/features/fuel/presentation/widgets/entry_tabs/tank_dip_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../../core/models/tank_dip_record.dart';
import '../../../../../core/services/service_registry.dart';
import '../../../../../core/models/day_entry.dart' as de;

class TankDipTab extends StatefulWidget {
  final VoidCallback? onSubmitted;
  final VoidCallback? onDraftsLoaded;

const TankDipTab({super.key, this.onSubmitted, this.onDraftsLoaded});

  @override
  State<TankDipTab> createState() => _TankDipTabState();
}

class _TankDipTabState extends State<TankDipTab>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  List<TankDipRecord> _drafts = [];
  bool _loading = true;
  bool _submitting = false;

  final String _businessDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final Map<String, TextEditingController> _openingCtrl = {};
  final Map<String, TextEditingController> _closingCtrl = {};
  final Map<String, FocusNode> _openingFocus = {};
  final Map<String, FocusNode> _closingFocus = {};
  final Map<String, String> _notes = {};

  static const _panelBg    = Color(0xFF0f172a);
  static const _panelBg2   = Color(0xFF111827);
  static const _panelBorder = Color(0xFF1f2937);
  static const _textPrimary   = Color(0xFFE5E7EB);
  static const _textSecondary = Color(0xFF9CA3AF);

  static const Map<String, Color> _fuelColors = {
    'PMS': Colors.green,
    'AGO': Colors.orange,
    'DPK': Colors.cyan,
    'Gas': Colors.purpleAccent,
    'LPG': Colors.purpleAccent,
  };

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  @override
  void dispose() {
    for (final c in _openingCtrl.values) c.dispose();
    for (final c in _closingCtrl.values) c.dispose();
    for (final f in _openingFocus.values) f.dispose();
    for (final f in _closingFocus.values) f.dispose();
    super.dispose();
  }

  /// Ensures a FocusNode exists for this fuel type's opening/closing
  /// fields, and wires it to autosave on blur (focus lost). This is
  /// what lets a typed-but-not-Enter-confirmed value survive a tab
  /// switch, since drafts are no longer blanket-saved on load.
  void _ensureFocusNodes(TankDipRecord d) {
    if (!_openingFocus.containsKey(d.fuelType)) {
      final node = FocusNode();
      node.addListener(() {
        if (!node.hasFocus) _saveDraft(d);
      });
      _openingFocus[d.fuelType] = node;
    }
    if (!_closingFocus.containsKey(d.fuelType)) {
      final node = FocusNode();
      node.addListener(() {
        if (!node.hasFocus) _saveDraft(d);
      });
      _closingFocus[d.fuelType] = node;
    }
  }

  Future<void> _loadDrafts() async {
    setState(() => _loading = true);

    await Services.tankDip.purgeEmptyDrafts(_businessDate);

    var drafts = await Services.tankDip.allForBusinessDate(_businessDate);

    if (drafts.isEmpty) {
      final entry = await Services.dayEntry.getOrCreate(_businessDate);
      final alreadySubmitted = entry.tankDip == de.DayEntryStatus.submitted
          || entry.submittedAt != null;

      if (!alreadySubmitted) {
        final fuelTypes = Services.tank.allTanks
            .map((t) => t.fuelType).toList()..sort();
        drafts = Services.tankDip.generateDrafts(
          businessDate: _businessDate,
          fuelTypes: fuelTypes,
        );
        // NOTE: these are in-memory placeholders only — do NOT persist
        // here. Saving on load would write empty rows to `tank_dips`
        // on every tab visit, which made the "unsubmitted drafts"
        // indicator stick even when the user never entered anything.
        // Real persistence happens in _saveDraft(), triggered by
        // field blur (see _ensureFocusNodes) or the notes dialog.
      } else {
        // Already submitted — generate display-only rows (not saved to DB)
        final fuelTypes = Services.tank.allTanks
            .map((t) => t.fuelType).toList()..sort();
        drafts = fuelTypes.map((fuel) => TankDipRecord(
          id: 'display_$fuel',
          businessDate: _businessDate,
          fuelType: fuel,
          openingLevel: 0.0,
          closingLevel: 0.0,
          createdAt: DateTime.now(),
          isSubmitted: true,
        )).toList();
      }
    }

    for (final d in drafts) {
      _openingCtrl[d.fuelType] ??= TextEditingController();
      _closingCtrl[d.fuelType] ??= TextEditingController();
      // Don't overwrite if already has values
      if (d.openingLevel > 0) _openingCtrl[d.fuelType]!.text = d.openingLevel.toStringAsFixed(0);
      if (d.closingLevel > 0) _closingCtrl[d.fuelType]!.text = d.closingLevel.toStringAsFixed(0);
      _notes[d.fuelType] = d.notes ?? '';
      _ensureFocusNodes(d);
    }

    if (!mounted) return;
    setState(() {
      _drafts = drafts;
      _loading = false;
    });
  }


  Future<void> _submitAll() async {
    // Validate: at least one fuel type must have readings
    final hasAnyReadings = _drafts.any((d) {
      final opening = double.tryParse(_openingCtrl[d.fuelType]?.text.trim() ?? '') ?? 0.0;
      final closing = double.tryParse(_closingCtrl[d.fuelType]?.text.trim() ?? '') ?? 0.0;
      return opening > 0 || closing > 0;
    });

    if (!hasAnyReadings) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one opening or closing reading before submitting'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    for (final d in _drafts) await _saveDraft(d);
    setState(() => _submitting = true);
    try {
      // Archive dips in DB + clear in-memory list
      await Services.tankDip.archiveForBusinessDate(_businessDate);

      await Services.dayEntry.submitSection(
        businessDate: _businessDate,
        section: 'TankDip',
        submittedAt: DateTime.now(),
      );

      // Clear controllers
      for (final c in _openingCtrl.values) c.clear();
      for (final c in _closingCtrl.values) c.clear();
      _notes.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tank dip readings submitted'),
            backgroundColor: Colors.green),
      );
      widget.onSubmitted?.call();

      // Reload fresh (will be empty since archived)
      await _loadDrafts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _saveDraft(TankDipRecord record) async {
    final opening = double.tryParse(_openingCtrl[record.fuelType]?.text.trim() ?? '') ?? 0.0;
    final closing = double.tryParse(_closingCtrl[record.fuelType]?.text.trim() ?? '') ?? 0.0;
    final notes = _notes[record.fuelType]?.trim();

    // Skip persisting a still-empty row — avoids writing a no-op
    // 0/0 row to the DB purely from a focus-in/focus-out with no
    // actual input, which would reintroduce the original bug.
    if (opening <= 0 && closing <= 0 && (notes == null || notes.isEmpty)) {
      return;
    }

    final updated = record.copyWith(
      openingLevel: opening,
      closingLevel: closing,
      notes: (notes == null || notes.isEmpty) ? null : notes,
    );
    await Services.tankDip.saveDraft(updated);
    setState(() {
      final idx = _drafts.indexWhere((d) => d.fuelType == record.fuelType);
      if (idx != -1) _drafts[idx] = updated;
    });
  }


  Future<void> _clearDrafts() async {
    for (final d in _drafts) await Services.tankDip.delete(d.id);
    for (final c in _openingCtrl.values) c.clear();
    for (final c in _closingCtrl.values) c.clear();
    _notes.clear();
    await _loadDrafts();
  }

  Future<void> _showNotesDialog(TankDipRecord record) async {
    final ctrl = TextEditingController(text: _notes[record.fuelType] ?? '');
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF0f172a),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _panelBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(
                        color: _fuelColors[record.fuelType] ?? Colors.grey,
                        shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('${record.fuelType} — Notes',
                    style: const TextStyle(color: _textPrimary,
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 3,
                style: const TextStyle(color: _textPrimary),
                decoration: InputDecoration(
                  hintText: 'Add a note for this reading...',
                  hintStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _panelBg2,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _panelBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.orange)),
                ),
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _notes[record.fuelType] = ctrl.text.trim());
                    Navigator.pop(context);
                    _saveDraft(record);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Save Note', style: TextStyle(color: Colors.white)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  double get _totalOpening => _drafts.fold(0.0, (s, d) =>
      s + (double.tryParse(_openingCtrl[d.fuelType]?.text.trim() ?? '') ?? d.openingLevel));

  double get _totalClosing => _drafts.fold(0.0, (s, d) =>
      s + (double.tryParse(_closingCtrl[d.fuelType]?.text.trim() ?? '') ?? d.closingLevel));

  double _capacityFor(String fuelType) {
    return Services.tank.allTanks
        .where((t) => t.fuelType == fuelType)
        .map((t) => t.capacity)
        .firstOrNull ?? double.infinity;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    if (_loading) return const Center(child: CircularProgressIndicator());

    return Container(
      color: const Color(0xFF0b1220),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT: entry form + buttons
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(children: [
                    const Text('Tank Dip Entry',
                        style: TextStyle(color: _textPrimary, fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _drafts.any((d) => d.isSubmitted)
                            ? Colors.green.withOpacity(0.15)
                            : Colors.orange.withOpacity(0.15),
                        border: Border.all(
                          color: _drafts.any((d) => d.isSubmitted)
                              ? Colors.green.withOpacity(0.4)
                              : Colors.orange.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        _drafts.any((d) => d.isSubmitted)
                            ? 'Submitted ✓'
                            : "Today's Drafts (${_drafts.length})",
                          style: TextStyle(
                            color: _drafts.any((d) => d.isSubmitted) ? Colors.green : Colors.orange,
                              fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  const Text('Enter physical opening & closing dip readings for each tank',
                      style: TextStyle(color: _textSecondary, fontSize: 12)),
                  const SizedBox(height: 16),

                  // Column headers
                  Padding(
                    padding: const EdgeInsets.only(left: 86, right: 8),
                    child: Row(children: [
                      Expanded(child: Text('Opening (L)',
                          style: TextStyle(color: _textSecondary,
                              fontSize: 11, fontWeight: FontWeight.w600))),
                      const SizedBox(width: 16),
                      Expanded(child: Text('Closing (L)',
                          style: TextStyle(color: _textSecondary,
                              fontSize: 11, fontWeight: FontWeight.w600))),
                      const SizedBox(width: 44),
                    ]),
                  ),
                  const SizedBox(height: 8),

                  // Fuel rows — scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(children: _drafts.map(_buildFuelRow).toList()),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Action buttons below rows
                  Row(children: [
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : _clearDrafts,
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text('Clear Drafts'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textSecondary,
                        side: const BorderSide(color: _panelBorder),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _submitting ? null : _submitAll,
                        icon: _submitting
                            ? const SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle_outline, size: 16),
                        label: Text(_submitting ? 'Submitting...' : 'Submit Dip'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),

          // RIGHT: summary panel
          SizedBox(
            width: 240,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 12),
                  _buildPerFuelCard(),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelRow(TankDipRecord d) {
    final color = _fuelColors[d.fuelType] ?? Colors.grey;
    final hasNote = (_notes[d.fuelType] ?? '').isNotEmpty;
    final capacity = _capacityFor(d.fuelType);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _panelBorder),
      ),
      child: Row(children: [
        // Fuel label
        SizedBox(
          width: 70,
          child: Row(children: [
            Container(width: 10, height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(d.fuelType, style: const TextStyle(
                color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
        const SizedBox(width: 16),
        // Opening
        Expanded(child: _dipField(
          controller: _openingCtrl[d.fuelType]!,
          focusNode: _openingFocus[d.fuelType]!,
          hint: 'Opening',
          capacity: capacity,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _saveDraft(d),
        )),
        const SizedBox(width: 16),
        // Closing
        Expanded(child: _dipField(
          controller: _closingCtrl[d.fuelType]!,
          focusNode: _closingFocus[d.fuelType]!,
          hint: 'Closing',
          capacity: capacity,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _saveDraft(d),
        )),
        const SizedBox(width: 8),
        // Notes icon
        Tooltip(
          message: hasNote ? (_notes[d.fuelType] ?? '') : 'Add note',
          child: IconButton(
            onPressed: () => _showNotesDialog(d),
            icon: Icon(
              hasNote ? Icons.note : Icons.note_add_outlined,
              color: hasNote ? Colors.orange : _textSecondary,
              size: 20,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _dipField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required double capacity,
    required ValueChanged<String> onChanged,
    required ValueChanged<String> onSubmitted,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
          color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textSecondary, fontSize: 13),
        filled: true,
        fillColor: _panelBg2,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _panelBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _panelBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.orange)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
      onChanged: (v) {
        final val = double.tryParse(v) ?? 0.0;
        if (capacity != double.infinity && val > capacity) {
          controller.text = capacity.toStringAsFixed(0);
          controller.selection =
              TextSelection.collapsed(offset: controller.text.length);
        }
        onChanged(v);
      },
      onSubmitted: onSubmitted,
    );
  }

  Widget _buildSummaryCard() {
    final variance = _totalClosing - _totalOpening;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Today's Dip (${_drafts.length} tanks)",
            style: const TextStyle(color: _textPrimary,
                fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 12),
        _summaryRow('Total Opening', '${_totalOpening.toStringAsFixed(0)} L', Colors.cyan),
        const SizedBox(height: 6),
        _summaryRow('Total Closing', '${_totalClosing.toStringAsFixed(0)} L', Colors.green),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(color: _panelBorder),
        ),
        _summaryRow(
          'Net Variance',
          '${variance >= 0 ? '+' : ''}${variance.toStringAsFixed(0)} L',
          variance >= 0 ? Colors.greenAccent : Colors.redAccent,
        ),
      ]),
    );
  }

  Widget _buildPerFuelCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Per Fuel Variance',
            style: TextStyle(color: _textPrimary,
                fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 12),
        ..._drafts.map((d) {
          final opening = double.tryParse(
              _openingCtrl[d.fuelType]?.text.trim() ?? '') ?? d.openingLevel;
          final closing = double.tryParse(
              _closingCtrl[d.fuelType]?.text.trim() ?? '') ?? d.closingLevel;
          final variance = closing - opening;
          final hasValues = opening > 0 || closing > 0;
          final color = _fuelColors[d.fuelType] ?? Colors.grey;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(d.fuelType, style: const TextStyle(
                  color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                hasValues
                    ? '${variance >= 0 ? '+' : ''}${variance.toStringAsFixed(0)} L'
                    : '—',
                style: TextStyle(
                  color: !hasValues ? _textSecondary
                      : variance >= 0 ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 12, fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _summaryRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 12)),
        Text(value, style: TextStyle(
            color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}