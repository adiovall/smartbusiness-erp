// lib/core/services/day_entry_service.dart

import '../models/day_entry.dart';
import '../../features/fuel/repositories/day_entry_repo.dart';

class DayEntryService {
  final DayEntryRepo repo;

  final Map<String, DayEntry> _cache = {};

  DayEntryService(this.repo);

  Future<DayEntry> getOrCreate(String date) async {
    if (_cache.containsKey(date)) return _cache[date]!;

    final fromDb = await repo.fetchByDate(date);
    final entry = fromDb ?? DayEntry(date: date);

    _cache[date] = entry;
    return entry;
  }

  Future<void> loadWeek(DateTime weekStart) async {
    final entries = await repo.fetchWeek(weekStart);
    for (final e in entries) {
      _cache[e.date] = e;
    }
  }

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

  /// ✅ NEW: submit only ONE section (e.g. Delivery only)
  /// This solves your redline.
  Future<void> submitSection({
    required String businessDate, // yyyy-MM-dd
    required String section, // 'Sale'|'Del'|'Exp'|'Set'
    required DateTime submittedAt,
  }) async {
    final entry = await getOrCreate(businessDate);

    switch (section) {
      case 'Sale':
        entry.sale = _finalize(entry.sale);
        break;
      case 'Del':
        entry.delivery = _finalize(entry.delivery);
        break;
      case 'Exp':
        entry.expense = _finalize(entry.expense);
        break;
      case 'Set':
        entry.settlement = _finalize(entry.settlement);
        break;
      default:
        throw Exception('Unknown section: $section');
    }

    // you still want submittedAt saved whenever anything is submitted
    entry.submittedAt = submittedAt;

    await repo.upsert(entry);
  }

  /// Submit whole day (green) for all draft sections
  Future<void> submitDay({
    required String businessDate,
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
    return s == DayEntryStatus.draft ? DayEntryStatus.submitted : s;
  }

  DayEntry? getFromCache(String date) => _cache[date];
}
