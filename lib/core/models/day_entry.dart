// lib/core/models/day_entry.dart

enum DayEntryStatus { none, draft, submitted }

class DayEntry {
  final String date; // yyyy-MM-dd (BUSINESS DATE)

  DayEntryStatus sale;
  DayEntryStatus delivery;
  DayEntryStatus expense;
  DayEntryStatus settlement;

  DateTime? submittedAt; // 👈 SUBMISSION DATE

  DayEntry({
    required this.date,
    this.sale = DayEntryStatus.none,
    this.delivery = DayEntryStatus.none,
    this.expense = DayEntryStatus.none,
    this.settlement = DayEntryStatus.none,
    this.submittedAt,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'sale': sale.index,
        'delivery': delivery.index,
        'expense': expense.index,
        'settlement': settlement.index,
        'submittedAt': submittedAt?.toIso8601String(),
      };

  factory DayEntry.fromJson(Map<String, dynamic> j) {
    return DayEntry(
      date: j['date'],
      sale: DayEntryStatus.values[j['sale']],
      delivery: DayEntryStatus.values[j['delivery']],
      expense: DayEntryStatus.values[j['expense']],
      settlement: DayEntryStatus.values[j['settlement']],
      submittedAt:
          j['submittedAt'] == null ? null : DateTime.parse(j['submittedAt']),
    );
  }
}
