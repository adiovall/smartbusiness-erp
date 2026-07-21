// lib/core/services/tank_dip_service.dart

import 'package:flutter/foundation.dart';
import '../models/tank_dip_record.dart';
import '../../features/fuel/repositories/tank_dip_repo.dart';

/// Manages today's tank dip readings for the currently open business
/// date. Mutating methods (saveDraft, delete, archiveForBusinessDate)
/// notify listeners so the tab UI and the top-level tab-bar dot stay
/// in sync — including when Send Data archives everything elsewhere
/// while this tab happens to be open. Pure reads (allForBusinessDate,
/// purgeEmptyDrafts) deliberately do NOT notify, since they're called
/// internally by the tab's own load routine; notifying on a read would
/// create a reload -> notify -> reload feedback loop.
class TankDipService with ChangeNotifier {
  final TankDipRepo repo;

  TankDipService({required this.repo});

  List<TankDipRecord> _todayDrafts = [];

  /// Unsubmitted rows only — matches Sale/Delivery/Expense's todayDrafts
  /// semantics, which is what the tab-bar dot indicator checks against.
  List<TankDipRecord> get todayDrafts =>
      _todayDrafts.where((d) => !d.isSubmitted).toList();

  // =====================
  // READS (no notifyListeners)
  // =====================

  Future<List<TankDipRecord>> allForBusinessDate(String businessDate) async {
    final drafts = await repo.fetchAllForBusinessDate(businessDate);
    _todayDrafts = drafts;
    return drafts;
  }

  /// Snapshot used by the outbox builder — deliberately ignores archive
  /// state, since Tank Dip rows may already be archived by the time
  /// Send Data runs (archiving now happens at Send Data itself, but
  /// this stays archive-agnostic as a safety net against any future
  /// timing changes between tabs).
  Future<List<TankDipRecord>> allForBusinessDateForOutbox(String businessDate) {
    return repo.fetchAllForBusinessDateAnyArchiveState(businessDate);
  }

  Future<int> countForBusinessDate(String businessDate) =>
      repo.countForBusinessDate(businessDate);

  Future<int> countSubmittedForBusinessDate(String businessDate) =>
      repo.countSubmittedForBusinessDate(businessDate);

  /// Removes stale rows that were never actually filled in (both
  /// readings still zero, no notes, not submitted). Safe to call on
  /// every tab load — it only ever touches genuinely empty rows, never
  /// anything with real input.
  Future<void> purgeEmptyDrafts(String businessDate) async {
    await repo.deleteEmptyDrafts(businessDate);
    _todayDrafts.removeWhere((d) =>
        d.businessDate == businessDate &&
        d.openingLevel == 0 &&
        d.closingLevel == 0 &&
        (d.notes == null || d.notes!.isEmpty) &&
        !d.isSubmitted);
  }

  // =====================
  // MUTATIONS (notifyListeners)
  // =====================

  Future<void> saveDraft(TankDipRecord record) async {
    await repo.insert(record);
    final idx = _todayDrafts.indexWhere((d) => d.id == record.id);
    if (idx != -1) {
      _todayDrafts[idx] = record;
    } else {
      _todayDrafts.add(record);
    }
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await repo.delete(id);
    _todayDrafts.removeWhere((d) => d.id == id);
    notifyListeners();
  }

  Future<void> archiveForBusinessDate(String businessDate) async {
    await repo.archiveForBusinessDate(businessDate);
    _todayDrafts = _todayDrafts.where((d) => d.businessDate != businessDate).toList();
    notifyListeners();
  }

  Future<void> deleteAllForBusinessDate(String businessDate) async {
    await repo.deleteForBusinessDate(businessDate);
    _todayDrafts.removeWhere((d) => d.businessDate == businessDate);
    notifyListeners();
  }

  Future<void> moveBusinessDate(String oldDate, String newDate) async {
    await repo.updateBusinessDate(oldDate, newDate);
    for (int i = 0; i < _todayDrafts.length; i++) {
      if (_todayDrafts[i].businessDate == oldDate) {
        // TankDipRecord fields are final except isSubmitted/isArchived via
        // copyWith, so rebuild via the model's own copyWith isn't available
        // for businessDate — construct a new record preserving everything else.
        final d = _todayDrafts[i];
        _todayDrafts[i] = TankDipRecord(
          id: d.id,
          businessDate: newDate,
          fuelType: d.fuelType,
          openingLevel: d.openingLevel,
          closingLevel: d.closingLevel,
          notes: d.notes,
          isSubmitted: d.isSubmitted,
          isArchived: d.isArchived,
          createdAt: d.createdAt,
        );
      }
    }
    notifyListeners();
  }

}