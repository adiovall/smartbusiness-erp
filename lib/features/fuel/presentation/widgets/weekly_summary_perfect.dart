// lib/features/fuel/presentation/widgets/weekly_summary_perfect.dart

import 'package:flutter/material.dart';
import '../../../../core/models/day_entry.dart' as de;

/* ===================== COLORS ===================== */
const panelBg = Color(0xFF0f172a);
const panelBorder = Color(0xFF1f2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);

class WeeklySummaryPerfect extends StatelessWidget {
  // Per-section status (Sale/Del/Exp/Set) for each day label, e.g. "Mon 15"
  final Map<String, Map<String, de.DayEntryStatus>> weeklyStatus;

  // NEW: whether each day has been fully "Sent" via the global Send Data button.
  // Key = same day label as weeklyStatus (e.g. "Mon 15").
  // true  -> entire row renders GREEN, permanently.
  // false -> fall back to per-section status (submitted -> YELLOW, none -> grey).
  final Map<String, bool> daySentStatus;

  const WeeklySummaryPerfect({
    super.key,
    required this.weeklyStatus,
    required this.daySentStatus,
  });

  @override
  Widget build(BuildContext context) {
    final sortedKeys = weeklyStatus.keys.toList()
      ..sort((a, b) {
        final dayA = a.split(' ').first;
        final dayB = b.split(' ').first;
        const order = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return order.indexOf(dayA).compareTo(order.indexOf(dayB));
      });

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Summary',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Table(
            columnWidths: const {0: FixedColumnWidth(54)},
            children: [
              _headerRow(),
              ...sortedKeys.map((key) {
                final isSent = daySentStatus[key] ?? false;
                return _dayRow(key, weeklyStatus[key]!, isSent);
              }),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _headerRow() {
    return TableRow(
      children: ['', 'Sales', 'Deli', 'Exp', 'St']
          .map(
            (h) => Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                h,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  TableRow _dayRow(
    String dayLabel,
    Map<String, de.DayEntryStatus> statuses,
    bool isSent,
  ) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            dayLabel,
            style: const TextStyle(fontSize: 9, color: textSecondary),
          ),
        ),
        _cell(statuses['Sale'] ?? de.DayEntryStatus.none, isSent),
        _cell(statuses['Del'] ?? de.DayEntryStatus.none, isSent),
        _cell(statuses['Exp'] ?? de.DayEntryStatus.none, isSent),
        _cell(statuses['Set'] ?? de.DayEntryStatus.none, isSent),
      ],
    );
  }

  Widget _cell(de.DayEntryStatus status, bool isSent) {
    Color color;
    IconData icon;

    if (isSent) {
      // Day has been globally sent via "Send Data" -> permanent green,
      // regardless of individual section status.
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (status == de.DayEntryStatus.submitted) {
      // Section submitted locally but day not yet sent -> yellow.
      color = Colors.amber;
      icon = Icons.check_circle;
    } else if (status == de.DayEntryStatus.draft) {
      color = Colors.amber;
      icon = Icons.check_circle;
    } else {
      color = const Color(0xFF475569);
      icon = Icons.circle_outlined;
    }

    return Center(
      child: Icon(icon, size: 12, color: color),
    );
  }
}