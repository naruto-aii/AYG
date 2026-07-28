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
    this.size = 180,
    this.strokeWidth = 14,
  });

  final double intakeKcal;
  final double targetKcal;
  final double remainingKcal;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final progress = targetKcal > 0
        ? (intakeKcal / targetKcal).clamp(0.0, 1.0)
        : 0.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(progress: progress, strokeWidth: strokeWidth),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('あと', style: AppTypography.heroLabel(context)),
              Text(
                remainingKcal.toStringAsFixed(0),
                style: AppTypography.heroValue(context),
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
  _RingPainter({required this.progress, required this.strokeWidth});

  final double progress;
  final double strokeWidth;

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
        colors: [AppColors.primaryGreen, AppColors.accentOrange],
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
    return oldDelegate.progress != progress;
  }
}
