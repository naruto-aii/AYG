import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Figma: CalorieRing（164×164）。
///
/// 12 時から反時計まわりに伸びる。オレンジの点はブランドの差し色として
/// Figma と同じ位置に固定で置いている（進捗とは連動しない）。
class CalorieRing extends StatelessWidget {
  const CalorieRing({
    super.key,
    required this.label,
    required this.value,
    required this.progress,
    this.unit = 'kcal',
    this.size = 164,
    this.progressColor,
  });

  final String label;
  final String value;
  final String unit;

  /// 0.0〜1.0。
  final double progress;
  final double size;
  final Color? progressColor;

  /// Figma の 164 を基準にした比率。
  static const double _designSize = 164;
  static const double _strokeWidth = 13;
  static const double _radius = 75.5;
  static const double _dotDiameter = 16.2;
  static const double _dotLeft = 129.698;
  static const double _dotTop = 29.674;
  static const double _labelTop = 40.4;
  static const double _valueTop = 50.7;
  static const double _unitTop = 103.4;

  double _s(double designValue) => designValue / _designSize * size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RingPainter(
                progress: progress.clamp(0.0, 1.0),
                radius: _s(_radius),
                strokeWidth: _s(_strokeWidth),
                color: progressColor ?? AppColors.green700,
              ),
            ),
          ),
          Positioned(
            left: _s(_dotLeft),
            top: _s(_dotTop),
            child: Container(
              width: _s(_dotDiameter),
              height: _s(_dotDiameter),
              decoration: const BoxDecoration(
                color: AppColors.orange500,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: _s(_labelTop),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.labelM.copyWith(
                color: AppColors.textSecondary,
                fontSize: _s(13),
              ),
            ),
          ),
          Positioned(
            left: _s(8),
            right: _s(8),
            top: _s(_valueTop),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                style: AppTypography.displayNumber.copyWith(
                  fontSize: _s(64),
                  letterSpacing: _s(-1.28),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: _s(_unitTop),
            child: Text(
              unit,
              textAlign: TextAlign.center,
              style: AppTypography.titleM.copyWith(fontSize: _s(16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.radius,
    required this.strokeWidth,
    required this.color,
  });

  final double progress;
  final double radius;
  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = AppColors.bgTrack
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) {
      return;
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // 12 時から反時計まわり。
    canvas.drawArc(rect, -math.pi / 2, -2 * math.pi * progress, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth;
}
