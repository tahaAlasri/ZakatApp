import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class HawlProgressGauge extends StatelessWidget {
  final int daysPassed;
  final int daysRemaining;
  final bool isCompleted;
  final DateTime? dueDate;

  const HawlProgressGauge({
    super.key,
    required this.daysPassed,
    required this.daysRemaining,
    required this.isCompleted,
    this.dueDate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const totalDays = 354; // السنة الهجرية القمرية
    final progress = (daysPassed / totalDays).clamp(0.0, 1.0);
    final percentage = (progress * 100).toInt();

    final gaugeColor = isCompleted
        ? AppColors.goldAccent
        : (progress > 0.85 ? Colors.orange : AppColors.emeraldPrimary);

    return Column(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(150, 150),
                painter: _GaugePainter(
                  progress: progress,
                  strokeColor: gaugeColor,
                  bgColor: isDark
                      ? Colors.grey.shade800
                      : Colors.grey.shade200,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.hourglass_bottom,
                    color: gaugeColor,
                    size: 24,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isCompleted ? '100%' : '$percentage%',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    isCompleted ? 'اكتمل الحول' : '$daysRemaining يوماً متبقية',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color strokeColor;
  final Color bgColor;

  _GaugePainter({
    required this.progress,
    required this.strokeColor,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;
    const strokeWidth = 12.0;

    // Background Arc (300 degrees from 120 deg to 420 deg)
    const startAngle = 135 * (math.pi / 180);
    const sweepTotal = 270 * (math.pi / 180);

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      bgPaint,
    );

    // Progress Arc
    final progressPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final currentSweep = sweepTotal * progress;
    if (currentSweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        currentSweep,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.bgColor != bgColor;
  }
}
