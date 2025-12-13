import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeeklySummaryPerfect extends StatelessWidget {
  final Map<String, Map<String, bool>> weeklyStatus;
  const WeeklySummaryPerfect({super.key, required this.weeklyStatus});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = today.subtract(Duration(days: today.weekday - 1));
    final days = List.generate(
      7,
      (i) => DateFormat('EEE dd').format(
        start.add(Duration(days: i)),
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Summary',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),

            Table(
              columnWidths: const {
                0: FixedColumnWidth(48), // slightly wider for "Mon 27"
              },
              children: [
                // HEADER
                TableRow(
                  children: ['', 'Sales', 'Deli', 'Exp', 'St']
                      .map(
                        (h) => Padding(
                          padding: const EdgeInsets.all(3),
                          child: Text(
                            h,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),

                // ROWS
                ...days.map(
                  (d) => TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(3),
                        child: Text(
                          d, // ✅ Mon 27
                          style: const TextStyle(fontSize: 9),
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
      ),
    );
  }

  Widget _c(bool v) => Center(
        child: Icon(
          v ? Icons.check_circle : Icons.circle_outlined,
          size: 12,
          color: v ? Colors.green : Colors.grey[700],
        ),
      );
}
