// lib/features/fuel/presentation/widgets/tank_levels_perfect.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/service_registry.dart';
import '../../../../core/models/tank_state.dart';

/* ===================== COLORS ===================== */
const panelBg = Color(0xFF0f172a);
const panelBorder = Color(0xFF1f2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);
const inputBorder = Color(0xFF334155);

class TankLevelsPerfect extends StatefulWidget {
  const TankLevelsPerfect({super.key});

  @override
  State<TankLevelsPerfect> createState() => _TankLevelsPerfectState();
}

class _TankLevelsPerfectState extends State<TankLevelsPerfect> {
  TankState? selectedTank;

  final TextEditingController capacityController = TextEditingController();
  final TextEditingController levelController = TextEditingController();

  final NumberFormat _fmt = NumberFormat.decimalPattern();

  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();

    // Ensure sample tanks exist ONCE
    Future.microtask(() async {
      await _ensureTanksExist();
      _selectInitialTank();
      if (mounted) setState(() => _bootstrapped = true);
    });

    Services.tank.addListener(_onTankDataChanged);
  }

  @override
  void dispose() {
    Services.tank.removeListener(_onTankDataChanged);
    capacityController.dispose();
    levelController.dispose();
    super.dispose();
  }

  /* ===================== ENSURE DATA ===================== */
  Future<void> _ensureTanksExist() async {
    // If tanks exist already -> no-op
    if (Services.tank.allTanks.isNotEmpty) return;

    await Services.tank.updateTank(
      TankState(fuelType: 'PMS', capacity: 33000, currentLevel: 15000),
    );
    await Services.tank.updateTank(
      TankState(fuelType: 'AGO', capacity: 33000, currentLevel: 12000),
    );
    await Services.tank.updateTank(
      TankState(fuelType: 'DPK', capacity: 10000, currentLevel: 3000),
    );
    await Services.tank.updateTank(
      TankState(fuelType: 'Gas', capacity: 8000, currentLevel: 2000),
    );
  }

  void _selectInitialTank() {
    final tanks = Services.tank.allTanks;
    if (tanks.isEmpty) {
      selectedTank = null;
      return;
    }

    // Keep current selection if possible
    if (selectedTank != null) {
      selectedTank = tanks.firstWhere(
        (t) => t.fuelType == selectedTank!.fuelType,
        orElse: () => tanks.first,
      );
    } else {
      selectedTank = tanks.first;
    }

    _updateControllers();
  }

  /* ===================== LISTENER ===================== */
  void _onTankDataChanged() {
    if (!mounted) return;
    setState(() {
      _selectInitialTank();
    });
  }

  void _updateControllers() {
    if (selectedTank == null) return;
    capacityController.text = selectedTank!.capacity.toStringAsFixed(0);
    levelController.text = selectedTank!.currentLevel.toStringAsFixed(0);
  }

  void _onTankChanged(TankState? newTank) {
    if (newTank == null) return;
    setState(() {
      selectedTank = newTank;
      _updateControllers();
    });
  }

  /* ===================== SAVE ===================== */
  Future<void> _saveChanges() async {
    if (selectedTank == null) return;

    final capText = capacityController.text.trim().replaceAll(',', '');
    final lvlText = levelController.text.trim().replaceAll(',', '');

    final newCapacity = double.tryParse(capText) ?? selectedTank!.capacity;
    final newLevel = double.tryParse(lvlText) ?? selectedTank!.currentLevel;

    if (newCapacity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capacity must be greater than 0')),
      );
      return;
    }

    if (newLevel < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Level cannot be negative')),
      );
      return;
    }

    if (newLevel > newCapacity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current level cannot exceed capacity')),
      );
      return;
    }

    final updatedTank = TankState(
      fuelType: selectedTank!.fuelType,
      capacity: newCapacity,
      currentLevel: newLevel,
    );

    await Services.tank.updateTank(updatedTank);

    if (!mounted) return;
    setState(() => selectedTank = updatedTank);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${updatedTank.fuelType} tank updated successfully')),
    );
  }

  /* ===================== UI HELPERS ===================== */

  InputDecoration _input(String label, {String? suffix}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffix,
      labelStyle: const TextStyle(color: textSecondary, fontSize: 12),
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: inputBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.green),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _numField({
    required TextEditingController controller,
    required String label,
    String? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: _input(label, suffix: suffix),
      style: const TextStyle(color: textPrimary),
      onSubmitted: (_) => _saveChanges(),
    );
  }

  String _n(num v) => _fmt.format(v.round());

  Color _levelColor(double v) => v > 50 ? Colors.green : v > 20 ? Colors.orange : Colors.red;

  String _meterStatus(double percent) {
    if (percent < 20) return 'CRITICAL';
    if (percent < 50) return 'LOW';
    return 'IN STOCK';
  }

  Color _meterStatusColor(double percent) {
    if (percent < 20) return Colors.red;
    if (percent < 50) return Colors.orange;
    return Colors.green;
  }

  /* ===================== UI ===================== */
  @override
  Widget build(BuildContext context) {
    final tanks = Services.tank.allTanks;

    // While bootstrapping, show skeleton to avoid flicker
    if (!_bootstrapped) {
      return _loadingCard();
    }

    if (tanks.isEmpty || selectedTank == null) {
      return _emptyState();
    }

    final percent = selectedTank!.percentage;
    final color = _levelColor(percent);

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Row(
            children: const [
              Text(
                'Tank Levels',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              Spacer(),
            ],
          ),
          const SizedBox(height: 12),

          // ✅ responsive settings row
          LayoutBuilder(
            builder: (context, c) {
              final tight = c.maxWidth < 520;

              final fuelDrop = DropdownButtonFormField<TankState>(
                value: selectedTank,
                isDense: true,
                isExpanded: true,
                dropdownColor: const Color(0xFF1e293b),
                style: const TextStyle(color: textPrimary),
                decoration: _input('Fuel'),
                items: tanks
                    .map(
                      (tank) => DropdownMenuItem(
                        value: tank,
                        child: Text(
                          tank.fuelType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _onTankChanged,
              );

              final cap = _numField(controller: capacityController, label: 'Capacity', suffix: 'L');
              final lvl = _numField(controller: levelController, label: 'Level', suffix: 'L');

              final saveBtn = SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _saveChanges,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              );

              if (!tight) {
                return Row(
                  children: [
                    Expanded(flex: 2, child: fuelDrop),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: cap),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: lvl),
                    const SizedBox(width: 12),
                    SizedBox(width: 110, child: saveBtn),
                  ],
                );
              }

              // Tight width -> wrap into two rows (no overflow)
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: fuelDrop),
                      const SizedBox(width: 12),
                      SizedBox(width: 110, child: saveBtn),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: cap),
                      const SizedBox(width: 12),
                      Expanded(child: lvl),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 18),

          // linear gauges
          ...tanks.map((t) {
            final p = t.percentage;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 58,
                    child: Text(
                      t.fuelType,
                      style: const TextStyle(fontSize: 11, color: textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: p / 100,
                        minHeight: 14,
                        backgroundColor: Colors.white.withOpacity(0.06),
                        color: _levelColor(p),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 42,
                    child: Text(
                      '${p.toInt()}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 18),

          // gauge
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    selectedTank!.fuelType,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: percent),
                    duration: const Duration(milliseconds: 900),
                    builder: (_, value, __) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 210,
                            height: 120,
                            child: CustomPaint(
                              painter: _NeedleGaugePainter(percent: value, color: color),
                            ),
                          ),
                          Positioned(
                            bottom: 6,
                            child: Text(
                              '${value.toInt()}%',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      Text(
                        '${_n(selectedTank!.currentLevel)} / ${_n(selectedTank!.capacity)} L', // ✅ commas
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withOpacity(0.35)),
                        ),
                        child: Text(
                          _meterStatus(percent),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _meterStatusColor(percent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder),
      ),
      child: const Center(
        child: Text(
          'No tank data available',
          style: TextStyle(color: textSecondary),
        ),
      ),
    );
  }

  Widget _loadingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/* ===================== PAINTER ===================== */
class _NeedleGaugePainter extends CustomPainter {
  final double percent;
  final Color color;

  _NeedleGaugePainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 12.0;
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - stroke;

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      bgPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi * (percent / 100),
      false,
      arcPaint,
    );

    final angle = pi + pi * (percent / 100);
    final needleLength = radius - 10;

    canvas.drawLine(
      center,
      Offset(
        center.dx + needleLength * cos(angle),
        center.dy + needleLength * sin(angle),
      ),
      Paint()
        ..color = color
        ..strokeWidth = 3,
    );

    canvas.drawCircle(center, 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _NeedleGaugePainter oldDelegate) =>
      oldDelegate.percent != percent || oldDelegate.color != color;
}
