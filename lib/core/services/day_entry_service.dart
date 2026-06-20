// lib/core/services/day_entry_service.dart

import '../models/day_entry.dart';
import '../../features/fuel/repositories/day_entry_repo.dart';
import 'sale_service.dart';
import 'delivery_service.dart';
import 'debt_service.dart';
import 'expense_service.dart';
import 'settlement_service.dart';

class DayEntryService {
  final DayEntryRepo repo;

  final SaleService saleService;
  final DeliveryService deliveryService;
  final DebtService debtService;
  final ExpenseService expenseService;
  final SettlementService settlementService;

  final Map<String, DayEntry> _cache = {};

  DayEntryService({
    required this.repo,
    required this.saleService,
    required this.deliveryService,
    required this.debtService,
    required this.expenseService,
    required this.settlementService,
  });

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

  Future<void> submitSection({
    required String businessDate,
    required String section,
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

    await repo.upsert(entry);
  }

  bool isDayAlreadySent(String businessDate) {
    final entry = _cache[businessDate];
    return entry?.submittedAt != null;
  }

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

  Future<void> correctBusinessDate({
    required String oldDate,
    required String newDate,
  }) async {
    if (oldDate == newDate) return;

    if (isDayAlreadySent(newDate)) {
      throw DaySentAlreadyException(newDate);
    }
    final newEntryFromDb = await repo.fetchByDate(newDate);
    if (newEntryFromDb?.submittedAt != null) {
      throw DaySentAlreadyException(newDate);
    }

    final oldEntry = await getOrCreate(oldDate);
    final newEntry = await getOrCreate(newDate);

    newEntry.sale = _mergeStatus(oldEntry.sale, newEntry.sale);
    newEntry.delivery = _mergeStatus(oldEntry.delivery, newEntry.delivery);
    newEntry.expense = _mergeStatus(oldEntry.expense, newEntry.expense);
    newEntry.settlement = _mergeStatus(oldEntry.settlement, newEntry.settlement);

    await repo.upsert(newEntry);

    await saleService.moveBusinessDate(oldDate, newDate);
    await deliveryService.moveBusinessDate(oldDate, newDate);
    await debtService.moveBusinessDate(oldDate, newDate);
    await expenseService.moveBusinessDate(oldDate, newDate);
    await settlementService.moveBusinessDate(oldDate, newDate);

    oldEntry.sale = DayEntryStatus.none;
    oldEntry.delivery = DayEntryStatus.none;
    oldEntry.expense = DayEntryStatus.none;
    oldEntry.settlement = DayEntryStatus.none;
    await repo.upsert(oldEntry);
  }

  DayEntryStatus _mergeStatus(DayEntryStatus a, DayEntryStatus b) {
    if (a == DayEntryStatus.submitted || b == DayEntryStatus.submitted) {
      return DayEntryStatus.submitted;
    }
    if (a == DayEntryStatus.draft || b == DayEntryStatus.draft) {
      return DayEntryStatus.draft;
    }
    return DayEntryStatus.none;
  }

  Future<List<DayEntry>> fetchUnsentDates() async {
    return repo.fetchUnsentDates();
  }

  DayEntryStatus _finalize(DayEntryStatus s) {
    return s == DayEntryStatus.draft ? DayEntryStatus.submitted : s;
  }

  DayEntry? getFromCache(String date) => _cache[date];
}

class DaySentAlreadyException implements Exception {
  final String businessDate;
  DaySentAlreadyException(this.businessDate);

  @override
  String toString() => 'Business date $businessDate has already been sent.';
}