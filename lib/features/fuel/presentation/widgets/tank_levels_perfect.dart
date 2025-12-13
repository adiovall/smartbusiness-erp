import 'package:flutter/material.dart';

class TankLevelsPerfect extends StatefulWidget {
  const TankLevelsPerfect({super.key});

  @override
  State<TankLevelsPerfect> createState() => _TankLevelsPerfectState();
}

class _TankLevelsPerfectState extends State<TankLevelsPerfect> {
  final fuels = ['Petrol (PMS)', 'Diesel (AGO)', 'Kerosene (HHK)', 'Gas (LPG)'];
  String selected = 'Petrol (PMS)';

  final TextEditingController capCtrl =
      TextEditingController(text: '33000');
  final TextEditingController levCtrl =
      TextEditingController(text: '18000');

  final Map<String, double> levels = {
    'Petrol (PMS)': 54.5,
    'Diesel (AGO)': 80.0,
    'Kerosene (HHK)': 56.0,
    'Gas (LPG)': 38.0,
  };

  void _recalculate() {
    final cap = double.tryParse(capCtrl.text) ?? 0;
    final lev = double.tryParse(levCtrl.text) ?? 0;
    if (cap <= 0) return;

    setState(() {
      levels[selected] = (lev / cap * 100).clamp(0, 100);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tank Levels',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // 🔹 FUEL TYPE + CAPACITY + LEVEL (ONE ROW)
            Row(
              children: [
                // Fuel type
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: selected,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Fuel',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    items: fuels
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.split(' ').first),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() => selected = v!);
                      _recalculate();
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Capacity
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: capCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _recalculate(),
                    decoration: const InputDecoration(
                      labelText: 'Capacity',
                      suffixText: 'L',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Level
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: levCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _recalculate(),
                    decoration: const InputDecoration(
                      labelText: 'Level',
                      suffixText: 'L',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 🔹 TANK BARS
            ...levels.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        e.key.split(' ').first,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: e.value / 100,
                        minHeight: 16,
                        backgroundColor: Colors.grey.shade800,
                        color: e.value > 50
                            ? Colors.green
                            : e.value > 20
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${e.value.toInt()}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
