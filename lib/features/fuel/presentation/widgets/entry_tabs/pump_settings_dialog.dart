import 'package:flutter/material.dart';
import '../../../../../core/services/service_registry.dart';

const _panelBg = Color(0xFF0f172a);
const _textPrimary = Color(0xFFE5E7EB);
const _textSecondary = Color(0xFF9CA3AF);
const _inputBorder = Color(0xFF334155);

class PumpSettingsDialog extends StatefulWidget {
  const PumpSettingsDialog({super.key});

  @override
  State<PumpSettingsDialog> createState() => _PumpSettingsDialogState();
}

class _PumpSettingsDialogState extends State<PumpSettingsDialog> {
  final fuels = const ['PMS', 'AGO', 'DPK', 'Gas'];
  final countCtrl = TextEditingController();

  // Working copy — nothing is persisted until Save is pressed.
  late Map<String, String> _assignments;

  @override
  void initState() {
    super.initState();
    _assignments = {
      for (final p in Services.pumpConfig.pumps) p.pumpNo: p.fuelType,
    };
    countCtrl.text = _assignments.isEmpty ? '' : _assignments.length.toString();
  }

  @override
  void dispose() {
    countCtrl.dispose();
    super.dispose();
  }

  void _regenerate() {
    final count = int.tryParse(countCtrl.text.trim());
    if (count == null || count <= 0 || count > 50) return;

    final updated = <String, String>{};
    for (int i = 1; i <= count; i++) {
      final key = i.toString();
      updated[key] = _assignments[key] ?? fuels.first;
    }
    setState(() => _assignments = updated);
  }

  Future<void> _save() async {
    await Services.pumpConfig.saveConfig(_assignments);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final pumpKeys = _assignments.keys.toList()
      ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));

    return Dialog(
      backgroundColor: _panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _inputBorder),
      ),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Configure Pumps',
                  style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'Set how many pumps this station has, then assign a fuel '
                'type to each. Sale entry will only show pumps that match '
                'the fuel type selected.',
                style: TextStyle(color: _textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: countCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: _textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Number of Pumps',
                        labelStyle: const TextStyle(color: _textSecondary),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                        isDense: true,
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: _inputBorder),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.orange),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _regenerate,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('Set'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (pumpKeys.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Enter a pump count and tap Set to begin.',
                      style: TextStyle(color: _textSecondary, fontSize: 12)),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: pumpKeys.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final pumpNo = pumpKeys[i];
                      final current = _assignments[pumpNo] ?? fuels.first;
                      return Row(
                        children: [
                          SizedBox(
                            width: 70,
                            child: Text('Pump $pumpNo',
                                style: const TextStyle(color: _textPrimary, fontSize: 13)),
                          ),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: current,
                              isDense: true,
                              dropdownColor: _panelBg,
                              style: const TextStyle(color: _textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.04),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: _inputBorder),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Colors.orange),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items: fuels
                                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => _assignments[pumpNo] = v);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: pumpKeys.isEmpty ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}