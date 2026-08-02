import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// 摂取 / 目標カロリーのリング表示。
class CalorieProgressRing extends StatelessWidget {
  const CalorieProgressRing({
    super.key,
    required this.intakeKcal,
    required this.targetKcal,
    required this.remainingKcal,
    this.isCalorieOverage = false,
    this.calorieOverageKcal = 0,
    this.size = 180,
    this.strokeWidth = 14,
  });

  final double intakeKcal;
  final double targetKcal;
  final double remainingKcal;
  final bool isCalorieOverage;
  final double calorieOverageKcal;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final progress = targetKcal > 0
        ? (intakeKcal / targetKcal).clamp(0.0, 1.0)
        : 0.0;
    final displayValue = isCalorieOverage
        ? calorieOverageKcal
        : remainingKcal.clamp(0.0, double.infinity);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress,
              strokeWidth: strokeWidth,
              isOverage: isCalorieOverage,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isCalorieOverage ? '超過' : 'あと',
                style: AppTypography.heroLabel(context),
              ),
              Text(
                displayValue.toStringAsFixed(0),
                style: AppTypography.heroValue(context)?.copyWith(
                  color: isCalorieOverage ? AppColors.accentOrange : null,
                ),
              ),
              Text(
                'kcal',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    this.isOverage = false,
  });

  final double progress;
  final double strokeWidth;
  final bool isOverage;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = AppColors.softGreen.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..shader = SweepGradient(
        colors: isOverage
            ? [
                AppColors.accentOrange,
                AppColors.accentOrange.withValues(alpha: 0.7),
              ]
            : [AppColors.primaryGreen, AppColors.accentOrange],
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 2 * math.pi, false, track);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isOverage != isOverage;
  }
}
