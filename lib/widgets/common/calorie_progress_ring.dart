import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
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
                isCalorieOverage ? '超過' : AppStrings.remainingToday,
                style: AppTypography.heroLabel(context),
              ),
              Text(
                displayValue.toStringAsFixed(0),
                style: AppTypography.heroValue(context).copyWith(
                  color: isCalorieOverage
                      ? AppColors.accentOrange
                      : AppColors.textPrimary,
                ),
              ),
              Text(
                'kcal',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppColors.textMuted),
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
    const start = -math.pi / 2;
    final sweep = 2 * math.pi * progress;

    final track = Paint()
      ..color = AppColors.bgTrack
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = isOverage ? AppColors.accentOrange : AppColors.bgPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 2 * math.pi, false, track);
    if (progress <= 0) {
      return;
    }
    canvas.drawArc(rect, start, sweep, false, progressPaint);

    final endAngle = start + sweep;
    final capCenter = Offset(
      center.dx + radius * math.cos(endAngle),
      center.dy + radius * math.sin(endAngle),
    );
    canvas.drawCircle(
      capCenter,
      strokeWidth * 0.55,
      Paint()..color = AppColors.accentOrange,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isOverage != isOverage;
  }
}
