import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const panelBg = Color(0xFF0f172a);
const panelBorder = Color(0xFF1f2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);

class WeeklySummaryPerfect extends StatelessWidget {
  final Map<String, Map<String, bool>> weeklyStatus;
  const WeeklySummaryPerfect({super.key, required this.weeklyStatus});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = today.subtract(Duration(days: today.weekday - 1));
    final days = List.generate(
      7,
      (i) => DateFormat('EEE dd').format(start.add(Duration(days: i))),
    );

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
            columnWidths: const {
              0: FixedColumnWidth(52),
            },
            children: [
              TableRow(
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
              ),
              ...days.map(
                (d) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontSize: 9,
                          color: textSecondary,
                        ),
                      ),
                    ),
                    _c(weeklyStatus[d]?['Sale'] ?? false),
                    _c(weeklyStatus[d]?['Del'] ?? false),
                    _c(weeklyStatus[d]?['Exp'] ?? false),
                    _c(weeklyStatus[d]?['Set'] ?? false),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _c(bool v) => Center(
        child: Icon(
          v ? Icons.check_circle : Icons.circle_outlined,
          size: 12,
          color: v ? Colors.green : const Color(0xFF475569),
        ),
      );
}
