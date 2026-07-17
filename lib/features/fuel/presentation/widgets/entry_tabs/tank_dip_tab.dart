// lib/features/fuel/presentation/widgets/entry_tabs/tank_dip_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../../core/models/tank_dip_record.dart';
import '../../../../../core/services/service_registry.dart';

class TankDipTab extends StatefulWidget {
  final Future<void> Function()? onSubmitted;
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

  String? _selectedFuel;
  String? _editingId;

  final oCtrl = TextEditingController();
  final cCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  String? _openingError;
  String? _closingError;

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
    Services.tankDip.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    oCtrl.dispose();
    cCtrl.dispose();
    notesCtrl.dispose();
    Services.tankDip.removeListener(_onServiceChanged);
    super.dispose();
  }

  List<String> get _availableFuelTypes {
    final allFuels = Services.tank.allTanks.map((t) => t.fuelType).toList()..sort();
    final recordedFuels = _drafts.map((d) => d.fuelType).toSet();
    final editingFuel = _editingId != null
        ? _drafts.where((d) => d.id == _editingId).map((d) => d.fuelType).firstOrNull
        : null;
    return allFuels.where((f) => !recordedFuels.contains(f) || f == editingFuel).toList();
  }

  void _syncSelectedFuel() {
    if (_editingId != null) return;
    final opts = _availableFuelTypes;
    if (opts.isEmpty) {
      _selectedFuel = null;
    } else if (_selectedFuel == null || !opts.contains(_selectedFuel)) {
      _selectedFuel = opts.first;
    }
  }

  void _onServiceChanged() {
    if (!mounted) return;
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    setState(() => _loading = true);

    await Services.tankDip.purgeEmptyDrafts(_businessDate);
    final drafts = await Services.tankDip.allForBusinessDate(_businessDate);

    if (!mounted) return;
    setState(() {
      _drafts = drafts;
      _loading = false;
      _syncSelectedFuel();
    });
  }

  void _clearInputs() {
    oCtrl.clear();
    cCtrl.clear();
    notesCtrl.clear();
    setState(() {
      _editingId = null;
      _openingError = null;
      _closingError = null;
      _syncSelectedFuel();
    });
  }

  void _toast(String msg, {bool green = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: green ? Colors.green : Colors.orange),
    );
  }

  double _capacityFor(String fuelType) {
    return Services.tank.allTanks
        .where((t) => t.fuelType == fuelType)
        .map((t) => t.capacity)
        .firstOrNull ?? double.infinity;
  }

  /// Validates a reading against the selected fuel's tank capacity.
  /// Returns an error message if it exceeds capacity, null otherwise.
  /// No clamping — the person sees exactly what's wrong and fixes it
  /// themselves, rather than the app silently rewriting their input.
  String? _capacityError(String text) {
    if (_selectedFuel == null) return null;
    final val = double.tryParse(text.trim());
    if (val == null) return null;
    final cap = _capacityFor(_selectedFuel!);
    if (cap != double.infinity && val > cap) {
      return 'Exceeds tank capacity (${cap.toStringAsFixed(0)} L)';
    }
    return null;
  }

  Future<void> _recordOrUpdate() async {
    if (_selectedFuel == null) return;

    // Re-validate right before saving, in case the fuel selection or
    // typed values changed since the last onChanged.
    setState(() {
      _openingError = _capacityError(oCtrl.text);
      _closingError = _capacityError(cCtrl.text);
    });

    if (_openingError != null || _closingError != null) {
      _toast('Fix the highlighted reading before saving');
      return;
    }

    final opening = double.tryParse(oCtrl.text.trim()) ?? 0.0;
    final closing = double.tryParse(cCtrl.text.trim()) ?? 0.0;
    final notes = notesCtrl.text.trim();

    if (opening <= 0 && closing <= 0) {
      _toast('Enter an opening or closing reading');
      return;
    }

    final existing = _editingId != null
        ? _drafts.where((d) => d.id == _editingId).firstOrNull
        : null;

    final base = existing ?? TankDipRecord(
      id: '${DateTime.now().millisecondsSinceEpoch}_$_selectedFuel',
      businessDate: _businessDate,
      fuelType: _selectedFuel!,
      openingLevel: 0,
      closingLevel: 0,
      createdAt: DateTime.now(),
    );

    final record = base.copyWith(
      openingLevel: opening,
      closingLevel: closing,
      notes: notes.isEmpty ? null : notes,
    );

    await Services.tankDip.saveDraft(record);
    _toast(existing == null ? 'Recorded' : 'Updated', green: true);
    _clearInputs();
    await _loadDrafts();
  }

  void _editDraft(TankDipRecord d) {
    if (d.isSubmitted) return;
    setState(() {
      _editingId = d.id;
      _selectedFuel = d.fuelType;
      oCtrl.text = d.openingLevel > 0 ? d.openingLevel.toStringAsFixed(0) : '';
      cCtrl.text = d.closingLevel > 0 ? d.closingLevel.toStringAsFixed(0) : '';
      notesCtrl.text = d.notes ?? '';
      _openingError = null;
      _closingError = null;
    });
  }

  Future<void> _deleteDraft(TankDipRecord d) async {
    if (d.isSubmitted) return;
    await Services.tankDip.delete(d.id);
    if (_editingId == d.id) _clearInputs();
    await _loadDrafts();
  }

  Future<void> _clearAllDrafts() async {
    final deletable = _drafts.where((d) => !d.isSubmitted).toList();
    if (deletable.isEmpty) return;
    for (final d in deletable) {
      await Services.tankDip.delete(d.id);
    }
    _clearInputs();
    await _loadDrafts();
  }

  bool get _canSubmit => _drafts.any((d) => !d.isSubmitted);

  Future<void> _submitAll() async {
    final unsubmitted = _drafts.where((d) => !d.isSubmitted).toList();
    if (unsubmitted.isEmpty) return;

    setState(() => _submitting = true);
    try {
      for (final d in unsubmitted) {
        await Services.tankDip.saveDraft(d.copyWith(isSubmitted: true));
      }

      _clearInputs();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tank dip readings submitted'), backgroundColor: Colors.green),
      );

      if (widget.onSubmitted != null) {
        await widget.onSubmitted!();
      }

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

  InputDecoration _input(String label, {String? suffix, bool hasError = false}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffix,
      labelStyle: const TextStyle(color: _textSecondary, fontSize: 12),
      filled: true,
      fillColor: _panelBg2,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: hasError ? Colors.redAccent : _panelBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: hasError ? Colors.redAccent : Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _numField({
    required TextEditingController ctrl,
    required String label,
    required String? error,
    required ValueChanged<String?> onError,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: _textPrimary),
          decoration: _input(label, suffix: 'L', hasError: error != null),
          onChanged: (v) {
            onError(_capacityError(v));
            setState(() {});
          },
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(error, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    final opts = _availableFuelTypes;
    final canRecord = _selectedFuel != null && _openingError == null && _closingError == null;

    return Container(
      color: const Color(0xFF0b1220),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tank Dip Entry',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textPrimary)),
            const SizedBox(height: 4),
            const Text('Enter physical opening & closing dip readings for each tank',
                style: TextStyle(color: _textSecondary, fontSize: 12)),
            const SizedBox(height: 16),

            if (opts.isEmpty && _editingId == null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _panelBorder),
                ),
                child: const Text('All tanks recorded for today.',
                    style: TextStyle(color: _textSecondary, fontSize: 12)),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _selectedFuel,
                      isDense: true,
                      isExpanded: true,
                      dropdownColor: _panelBg,
                      decoration: _input('Fuel'),
                      style: const TextStyle(color: _textPrimary, fontSize: 13),
                      items: opts.map((f) => DropdownMenuItem(
                            value: f,
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 8, height: 8,
                                  decoration: BoxDecoration(
                                      color: _fuelColors[f] ?? Colors.grey, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text(f),
                            ]),
                          )).toList(),
                      onChanged: _editingId != null ? null : (v) {
                        setState(() {
                          _selectedFuel = v;
                          // Fuel changed — re-check whatever's already typed
                          _openingError = _capacityError(oCtrl.text);
                          _closingError = _capacityError(cCtrl.text);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _numField(
                      ctrl: oCtrl,
                      label: 'Opening',
                      error: _openingError,
                      onError: (e) => _openingError = e,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _numField(
                      ctrl: cCtrl,
                      label: 'Closing',
                      error: _closingError,
                      onError: (e) => _closingError = e,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: notesCtrl,
                      style: const TextStyle(color: _textPrimary),
                      decoration: _input('Note (optional)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: canRecord ? _recordOrUpdate : null,
                      icon: Icon(_editingId == null ? Icons.save : Icons.update, size: 18),
                      label: Text(_editingId == null ? 'Save' : 'Update'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 24),

            Text('Recorded Dips (${_drafts.length})',
                style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 10),
            _tableHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: _drafts.isEmpty
                  ? const Center(child: Text('No dips recorded yet.', style: TextStyle(color: _textSecondary)))
                  : ListView.separated(
                      itemCount: _drafts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _tableRow(_drafts[i]),
                    ),
            ),

            const SizedBox(height: 12),
            Row(children: [
              OutlinedButton.icon(
                onPressed: _submitting ? null : _clearAllDrafts,
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear Drafts'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textSecondary,
                  side: const BorderSide(color: _panelBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_submitting || !_canSubmit) ? null : _submitAll,
                  icon: _submitting
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline, size: 16),
                  label: Text(_submitting ? 'Submitting...' : 'Submit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader() {
    const h = TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 117, 157, 244).withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _panelBorder),
      ),
      child: const Row(children: [
        SizedBox(width: 70, child: Text('Fuel', style: h)),
        Expanded(child: Text('Opening', style: h)),
        Expanded(child: Text('Closing', style: h)),
        Expanded(child: Text('Variance', style: h)),
        SizedBox(width: 80),
      ]),
    );
  }

  Widget _tableRow(TankDipRecord d) {
    final isEditing = _editingId == d.id;
    final isEditable = !d.isSubmitted;
    final variance = d.closingLevel - d.openingLevel;
    final color = _fuelColors[d.fuelType] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isEditing ? Colors.orange.withOpacity(0.12) : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isEditing
              ? Colors.orange.withOpacity(0.5)
              : (d.isSubmitted ? Colors.green.withOpacity(0.35) : _panelBorder),
        ),
      ),
      child: Row(children: [
        SizedBox(
          width: 70,
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(d.fuelType, style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
        Expanded(child: Text('${d.openingLevel.toStringAsFixed(0)} L', style: const TextStyle(color: _textPrimary, fontSize: 12))),
        Expanded(child: Text('${d.closingLevel.toStringAsFixed(0)} L', style: const TextStyle(color: _textPrimary, fontSize: 12))),
        Expanded(
          child: Text(
            '${variance >= 0 ? '+' : ''}${variance.toStringAsFixed(0)} L',
            style: TextStyle(
              color: variance >= 0 ? Colors.greenAccent : Colors.redAccent,
              fontSize: 12, fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          width: 80,
          child: isEditable
              ? Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (d.notes?.isNotEmpty ?? false)
                    Tooltip(message: d.notes!, child: const Icon(Icons.note, color: Colors.orange, size: 16)),
                  Tooltip(
                    message: 'Edit',
                    child: InkWell(
                      onTap: () => _editDraft(d),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.edit, color: _textSecondary, size: 16),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Delete',
                    child: InkWell(
                      onTap: () => _deleteDraft(d),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.delete, color: Colors.redAccent, size: 16),
                      ),
                    ),
                  ),
                ])
              : const Align(alignment: Alignment.centerRight, child: Icon(Icons.lock, color: Colors.grey, size: 16)),
        ),
      ]),
    );
  }
}