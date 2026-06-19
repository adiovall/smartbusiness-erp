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
  Future<void> markSubmitted(String date, String type) async {
    final entry = await getOrCreate(date);

    switch (type) {
      case 'Sale':
        entry.sale = DayEntryStatus.submitted;
        break;
      case 'Del':
        entry.delivery = DayEntryStatus.submitted;
        break;
      case 'Exp':
        entry.expense = DayEntryStatus.submitted;
        break;
      case 'Set':
        entry.settlement = DayEntryStatus.submitted;
        break;
    }

    await repo.upsert(entry);
  }

  /// Submit only ONE section (e.g. Delivery only).
  /// This is a SECTION-LEVEL submit — it does NOT mean the whole day
  /// has been sent to the analysis server. That only happens in submitDay().
  /// So: do NOT touch entry.submittedAt here.
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

    // ❌ removed: entry.submittedAt = submittedAt;
    // submittedAt is reserved for the GLOBAL "Send Data" action only.
    // Section-level submits should only ever render YELLOW, never GREEN.

    await repo.upsert(entry);
  }

  Future<List<DayEntry>> fetchUnsentDates() async {
    return repo.fetchUnsentDates();
  }

  /// Returns true if this business date has ALREADY been sent
  /// (used to block re-sending and show "already sent" message).
  bool isDayAlreadySent(String businessDate) {
    final entry = _cache[businessDate];
    return entry?.submittedAt != null;
  }

  /// Submit whole day (green, permanent) for all sections.
  /// Throws if this business date was already sent, so the caller
  /// can show a blocking "already sent" message instead of resending.
  Future<void> submitDay({
    required String businessDate,
    required DateTime submittedAt,
  }) async {
    final entry = await getOrCreate(businessDate);

    if (entry.submittedAt != null) {
      throw DaySentAlreadyException(businessDate);
    }

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

/// Thrown when submitDay() is called for a business date that
/// has already been sent. UI should catch this and show a
/// blocking "already sent" message — no resend allowed.
class DaySentAlreadyException implements Exception {
  final String businessDate;
  DaySentAlreadyException(this.businessDate);

  @override
  String toString() => 'Business date $businessDate has already been sent.';
}