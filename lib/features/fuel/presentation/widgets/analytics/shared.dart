// lib/features/fuel/presentation/widgets/analytics/analytics_shared.dart
//
// Shared colors, money formatter, and small reusable widgets used
// across all analytics view modules (Trends, Insight, Reconciliation,
// Day Detail). Keeping these in one place means every view stays
// visually consistent without each file redefining its own constants.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const panelBg = Color(0xFF0f172a);
const panelBg2 = Color(0xFF111827);
const panelBorder = Color(0xFF1f2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);

final moneyFmt = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

/// A small bordered KPI-style card: label on top, big colored value
/// below. Used by every analytics view for revenue/expense/etc totals.
Widget summaryCard(String label, double value, Color color) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        Text(
          moneyFmt.format(value),
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

/// A small colored-dot + label pair, used in chart legends.
Widget legendItem(String label, Color color) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: textSecondary, fontSize: 12)),
    ],
  );
}

/// A horizontally-scrolling toggle/period-selector button, used by
/// the Trends/Insight period selectors and the main view toggle bar.
Widget pillButton(String label, bool active, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? Colors.orange.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? Colors.orange : panelBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.orange : textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    ),
  );
}

/// A themed date picker matching the analytics screens' dark/orange
/// styling, used by both Trends' custom range and Insight (if needed).
Future<DateTime?> showThemedDatePicker(BuildContext context, {DateTime? initial}) {
  return showDatePicker(
    context: context,
    initialDate: initial ?? DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime.now(),
    builder: (context, child) => Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: Colors.orange, surface: Color(0xFF020617)),
      ),
      child: child!,
    ),
  );
}