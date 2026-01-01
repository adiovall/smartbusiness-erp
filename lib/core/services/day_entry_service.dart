// lib/core/services/day_entry_service.dart

import '../models/day_entry.dart';
import '../../features/fuel/repositories/day_entry_repo.dart';

class DayEntryService {
  final DayEntryRepo repo;

  /// In-memory cache for fast UI updates
  final Map<String, DayEntry> _cache = {};

  DayEntryService(this.repo);

  /* ===================== LOAD ===================== */

  /// Get entry for a date or create a new one
  Future<DayEntry> getOrCreate(String date) async {
    if (_cache.containsKey(date)) return _cache[date]!;

    final fromDb = await repo.fetchByDate(date);
    final entry = fromDb ?? DayEntry(date: date);

    _cache[date] = entry;
    return entry;
  }

  /// Load a full week into cache (used by weekly summary)
  Future<void> loadWeek(DateTime weekStart) async {
    final entries = await repo.fetchWeek(weekStart);
    for (final e in entries) {
      _cache[e.date] = e;
    }
  }

  /* ===================== DRAFT ===================== */

  /// Mark a section as draft (yellow)
  Future<void> markDraft(String date, String type) async {
    final entry = await getOrCreate(date);

    switch (type) {
      case 'Sale':
        entry.sale = DayEntryStatus.draft;
        break;
      case 'Del':
        entry.delivery = DayEntryStatus.draft;
        break;
      case 'Exp':
        entry.expense = DayEntryStatus.draft;
        break;
      case 'Set':
        entry.settlement = DayEntryStatus.draft;
        break;
    }

    await repo.upsert(entry);
  }

  /* ===================== SUBMIT ===================== */

  /// Submit day (green) with editable submission date
  Future<void> submitDay({
    required String businessDate, // yyyy-MM-dd
    required DateTime submittedAt,
  }) async {
    final entry = await getOrCreate(businessDate);

    entry
      ..sale = _finalize(entry.sale)
      ..delivery = _finalize(entry.delivery)
      ..expense = _finalize(entry.expense)
      ..settlement = _finalize(entry.settlement)
      ..submittedAt = submittedAt;

    await repo.upsert(entry);
  }

  DayEntryStatus _finalize(DayEntryStatus s) {
    return s == DayEntryStatus.draft
        ? DayEntryStatus.submitted
        : s;
  }

  /* ===================== READ ===================== */

  DayEntry? getFromCache(String date) => _cache[date];
}
