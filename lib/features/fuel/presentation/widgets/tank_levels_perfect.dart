// lib/features/fuel/presentation/widgets/tank_levels_perfect.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/services/service_registry.dart';
import '../../../../core/models/tank_state.dart';

/* ===================== COLORS ===================== */
const panelBg = Color(0xFF0f172a);
const panelBorder = Color(0xFF1f2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);

/* ===================== WIDGET ===================== */
class TankLevelsPerfect extends StatefulWidget {
  const TankLevelsPerfect({super.key});

  @override
  State<TankLevelsPerfect> createState() => _TankLevelsPerfectState();
}

class _TankLevelsPerfectState extends State<TankLevelsPerfect> {
  late TankState selectedTank;
  final TextEditingController capacityController = TextEditingController();
  final TextEditingController levelController = TextEditingController();

  @override
void initState() {
  super.initState();
  final tanks = Services.tank.allTanks;
  selectedTank = tanks.isNotEmpty ? tanks.first : TankState(fuelType: 'PMS', capacity: 33000, currentLevel: 0);
  _updateControllers();

  // Listen for any tank changes (e.g., from delivery/sales)
  Services.tank.addListener(_onTankDataChanged);
}

  @override
  void dispose() {
    Services.tank.removeListener(_onTankDataChanged);
    capacityController.dispose();
    levelController.dispose();
    super.dispose();
  }

  void _onTankDataChanged() {
    setState(() {
      final tanks = Services.tank.allTanks;
      // Re-select current tank or fallback
      selectedTank = tanks.firstWhere(
        (t) => t.fuelType == selectedTank.fuelType,
        orElse: () => tanks.first,
      );
      _updateControllers();
    });
  }

  void _updateControllers() {
    capacityController.text = selectedTank.capacity.toStringAsFixed(0);
    levelController.text = selectedTank.currentLevel.toStringAsFixed(0);
  }

  void _onTankChanged(TankState? newTank) {
    if (newTank != null) {
      setState(() {
        selectedTank = newTank;
        _updateControllers();
      });
    }
  }

  // Inside _TankLevelsPerfectState class

void _saveChanges() async {
  final newCapacity = double.tryParse(capacityController.text) ?? selectedTank.capacity;
  final newLevel = double.tryParse(levelController.text) ?? selectedTank.currentLevel;

  if (newLevel > newCapacity) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Current level cannot exceed capacity')),
    );
    return;
  }

  // Create updated tank instance
  final updatedTank = TankState(
    fuelType: selectedTank.fuelType,
    capacity: newCapacity,
    currentLevel: newLevel,
  );

  // Update via service → triggers notifyListeners()
  await Services.tank.updateTank(updatedTank);

  // Update local selected reference
  setState(() {
    selectedTank = updatedTank;
  });

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('${updatedTank.fuelType} tank updated successfully')),
  );
}

  @override
  Widget build(BuildContext context) {
    final tanks = Services.tank.allTanks;

    if (tanks.isEmpty) {
      return _emptyState();
    }

    // Ensure selectedTank is always valid
    if (!tanks.contains(selectedTank)) {
      selectedTank = tanks.first;
      _updateControllers();
    }

    final percent = selectedTank.percentage;

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tank Levels',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          /* ===== TANK SETTINGS HEADER (RESTORED!) ===== */
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<TankState>(
                  value: selectedTank,
                  decoration: const InputDecoration(
                    labelText: 'Fuel',
                    labelStyle: TextStyle(color: textSecondary, fontSize: 12),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  dropdownColor: const Color(0xFF1e293b),
                  style: const TextStyle(color: textPrimary),
                  items: tanks.map((tank) {
                    return DropdownMenuItem(
                      value: tank,
                      child: Text(tank.fuelType),
                    );
                  }).toList(),
                  onChanged: _onTankChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: capacityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Capacity (L)',
                    labelStyle: TextStyle(color: textSecondary, fontSize: 12),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  style: const TextStyle(color: textPrimary),
                  onSubmitted: (_) => _saveChanges(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: levelController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Level (L)',
                    labelStyle: TextStyle(color: textSecondary, fontSize: 12),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  style: const TextStyle(color: textPrimary),
                  onSubmitted: (_) => _saveChanges(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.save, color: Colors.green),
                tooltip: 'Save Changes',
                onPressed: _saveChanges,
              ),
            ],
          ),

          const SizedBox(height: 20),

          /* ===== LINEAR GAUGES ===== */
          ...tanks.map((t) {
            final p = t.percentage;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      t.fuelType,
                      style: const TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: p / 100,
                      minHeight: 16,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      color: _levelColor(p),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
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

          const SizedBox(height: 28),

          /* ===== NEEDLE GAUGE (SELECTED TANK) ===== */
          _needleGauge(selectedTank),
        ],
      ),
    );
  }

  /* ===================== NEEDLE GAUGE ===================== */
  Widget _needleGauge(TankState t) {
    final percent = t.percentage;
    final color = _levelColor(percent);

    return Center(
      child: Column(
        children: [
          Text(
            t.fuelType,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percent),
            duration: const Duration(milliseconds: 1000),
            builder: (_, value, __) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 110,
                    child: CustomPaint(
                      painter: _NeedleGaugePainter(percent: value, color: color),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    child: Text(
                      '${value.toInt()}%',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${t.currentLevel.toStringAsFixed(0)} / ${t.capacity.toStringAsFixed(0)} L',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
              ),
              const SizedBox(width: 8),
              Text(
                _meterStatus(percent),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: _meterStatusColor(percent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /* ===================== HELPERS ===================== */
  double _percent(TankState t) => t.percentage;

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
}

/* ===================== NEEDLE PAINTER ===================== */
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
      Offset(center.dx + needleLength * cos(angle), center.dy + needleLength * sin(angle)),
      Paint()..color = color..strokeWidth = 3,
    );

    canvas.drawCircle(center, 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _NeedleGaugePainter oldDelegate) => oldDelegate.percent != percent;
}

