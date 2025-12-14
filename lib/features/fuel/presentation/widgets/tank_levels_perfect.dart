import 'dart:math';
import 'package:flutter/material.dart';

/* ===================== COLORS ===================== */

const panelBg = Color(0xFF0f172a);
const panelBorder = Color(0xFF1f2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);
const inputBorder = Color(0xFF334155);

/* ===================== WIDGET ===================== */

class TankLevelsPerfect extends StatefulWidget {
  const TankLevelsPerfect({super.key});

  @override
  State<TankLevelsPerfect> createState() => _TankLevelsPerfectState();
}

class _TankLevelsPerfectState extends State<TankLevelsPerfect> {
  final fuels = ['Petrol (PMS)', 'Diesel (AGO)', 'Kerosene (HHK)', 'Gas (LPG)'];
  String selected = 'Petrol (PMS)';

  final TextEditingController capCtrl = TextEditingController(text: '33000');
  final TextEditingController levCtrl = TextEditingController(text: '18000');

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

  Color _levelColor(double v) =>
      v > 50 ? Colors.green : v > 20 ? Colors.orange : Colors.red;

  InputDecoration _inputDecoration(String label, {String? suffix}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffix,
      labelStyle: const TextStyle(color: textSecondary),
      suffixStyle: const TextStyle(color: textSecondary),
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: inputBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.green),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = levels[selected]!;
    final levelColor = _levelColor(level);
    final isLow = level < 20;

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20), // 👈 bottom space
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

          /* ===== Fuel + Capacity + Level ===== */
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48, // 🔥 FIXES pixel issue
                  child: DropdownButtonFormField<String>(
                    value: selected,
                    isDense: true,
                    isExpanded: true,
                    dropdownColor: panelBg,
                    decoration: _inputDecoration('Fuel'),
                    items: fuels
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(color: textPrimary),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() => selected = v!);
                      _recalculate();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextField(
                    controller: capCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _recalculate(),
                    decoration:
                        _inputDecoration('Capacity', suffix: 'L'),
                    style: const TextStyle(color: textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextField(
                    controller: levCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _recalculate(),
                    decoration:
                        _inputDecoration('Level', suffix: 'L'),
                    style: const TextStyle(color: textPrimary),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          /* ===== Animated Linear Gauges ===== */
          ...levels.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      e.key.split(' ').first,
                      style: const TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: e.value / 100),
                      duration:
                          const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, value, __) {
                        return LinearProgressIndicator(
                          value: value,
                          minHeight: 16,
                          backgroundColor:
                              Colors.white.withOpacity(0.06),
                          color: _levelColor(e.value),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${e.value.toInt()}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 26),

          /* ===== NEEDLE GAUGE ===== */
          Center(
            child: Column(
              children: [
                // Fuel label
                Text(
                  selected.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),

                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: level),
                  duration:
                      const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
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
                              color: levelColor,
                            ),
                          ),
                        ),

                        if (isLow)
                          TweenAnimationBuilder<double>(
                            tween:
                                Tween(begin: 0.6, end: 1.0),
                            duration: const Duration(
                                milliseconds: 700),
                            curve: Curves.easeInOut,
                            builder: (_, scale, __) {
                              return Transform.scale(
                                scale: scale,
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red,
                                  size: 26,
                                ),
                              );
                            },
                          ),

                        Positioned(
                          bottom: 6,
                          child: Text(
                            '${value.toInt()}%',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: levelColor,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 10), // 👈 bottom breathing space
        ],
      ),
    );
  }
}

/* ===================== NEEDLE GAUGE PAINTER ===================== */

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

    final needlePaint = Paint()
      ..color = color
      ..strokeWidth = 3;

    canvas.drawLine(
      center,
      Offset(
        center.dx + needleLength * cos(angle),
        center.dy + needleLength * sin(angle),
      ),
      needlePaint,
    );

    canvas.drawCircle(
      center,
      5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _NeedleGaugePainter oldDelegate) =>
      oldDelegate.percent != percent;
}
