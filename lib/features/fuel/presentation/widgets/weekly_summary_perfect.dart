// lib/features/fuel/presentation/widgets/weekly_summary_perfect.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/day_entry.dart' as de;

/* ===================== COLORS ===================== */
const panelBg = Color(0xFF0f172a);
const panelBorder = Color(0xFF1f2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);

class WeeklySummaryPerfect extends StatelessWidget {
  // Change from List<DayEntry> to your map structure
  final Map<String, Map<String, de.DayEntryStatus>> weeklyStatus;

  const WeeklySummaryPerfect({
    super.key,
    required this.weeklyStatus,
  });

  @override
  Widget build(BuildContext context) {
    // Sort days: Mon → Sun (assuming keys are like "Mon 15")
    final sortedKeys = weeklyStatus.keys.toList()
      ..sort((a, b) {
        // Extract day name for sorting
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
              ...sortedKeys.map((key) => _dayRow(key, weeklyStatus[key]!)),
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

  TableRow _dayRow(String dayLabel, Map<String, de.DayEntryStatus> statuses) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            dayLabel,
            style: const TextStyle(fontSize: 9, color: textSecondary),
          ),
        ),
        _cell(statuses['Sale'] ?? de.DayEntryStatus.none),
        _cell(statuses['Del'] ?? de.DayEntryStatus.none),
        _cell(statuses['Exp'] ?? de.DayEntryStatus.none),
        _cell(statuses['Set'] ?? de.DayEntryStatus.none),
      ],
    );
  }

  Widget _cell(de.DayEntryStatus status) {
    Color color;
    IconData icon;

    switch (status) {
      case de.DayEntryStatus.submitted:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case de.DayEntryStatus.draft:
        color = Colors.amber;
        icon = Icons.check_circle;
        break;
      default:
        color = const Color(0xFF475569);
        icon = Icons.circle_outlined;
    }

    return Center(
      child: Icon(icon, size: 12, color: color),
    );
  }
}