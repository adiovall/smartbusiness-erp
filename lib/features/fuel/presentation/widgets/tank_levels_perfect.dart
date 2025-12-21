// lib/features/fuel/presentation/widgets/tank_levels_perfect.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/models/tank_state.dart';

/* ===================== COLORS ===================== */

const panelBg = Color(0xFF0f172a);
const panelBorder = Color(0xFF1f2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);

/* ===================== WIDGET ===================== */

class TankLevelsPerfect extends StatelessWidget {
  final List<TankState> tanks;

  const TankLevelsPerfect({
    super.key,
    required this.tanks,
  });

  /* ===================== HELPERS ===================== */

  double _percent(TankState t) =>
      t.capacity <= 0 ? 0 : (t.currentLevel / t.capacity * 100).clamp(0, 100);

  Color _levelColor(double v) =>
      v > 50 ? Colors.green : v > 20 ? Colors.orange : Colors.red;

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

  /* ===================== BUILD ===================== */

  @override
  Widget build(BuildContext context) {
    if (tanks.isEmpty) {
      return _emptyState();
    }

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
          const SizedBox(height: 16),

          /* ===== LINEAR GAUGES ===== */
          ...tanks.map((t) {
            final percent = _percent(t);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      t.fuelType,
                      style: const TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      minHeight: 16,
                      backgroundColor:
                          Colors.white.withOpacity(0.06),
                      color: _levelColor(percent),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${percent.toInt()}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 28),

          /* ===== NEEDLE GAUGE (FIRST TANK) ===== */
          _needleGauge(tanks.first),
        ],
      ),
    );
  }

  /* ===================== NEEDLE ===================== */

  Widget _needleGauge(TankState t) {
    final percent = _percent(t);
    final color = _levelColor(percent);
    final isLow = percent < 20;

    return Center(
      child: Column(
        children: [
          Text(
            t.fuelType,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
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
                      painter: _NeedleGaugePainter(
                        percent: value,
                        color: color,
                      ),
                    ),
                  ),

                  if (isLow)
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 26,
                    ),

                  Positioned(
                    bottom: 6,
                    child: Text(
                      '${value.toInt()}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
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

  _NeedleGaugePainter({
    required this.percent,
    required this.color,
  });

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
      oldDelegate.percent != percent;
}
