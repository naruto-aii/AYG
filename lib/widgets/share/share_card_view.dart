import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../services/share_card_content.dart';
import '../../services/share_links.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// 今日の摂取カロリーの共有カード。
///
/// 地のグラデーション、リングの描き方、超過のオレンジと「超過」、
/// Zen Maru Gothic はホームウィジェット（`docs/design/widget`）に揃える。
class ShareCardView extends StatelessWidget {
  const ShareCardView({super.key, required this.content});

  final ShareCardContent content;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _WidgetBackground(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(dateLabel: content.dateLabel),
                  const SizedBox(height: 6),
                  Text(
                    content.eyebrow,
                    maxLines: 1,
                    style: _text(
                      AppTypography.titleL,
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Center(child: _ShareGoalRing(content: content)),
                  ),
                  const SizedBox(height: 4),
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      AppStrings.loginTagline,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                        height: 1.2,
                        color: Color(0xC7FFFFFF),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _DownloadFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// green600 → green800 → green900。右上に green300 の淡い光。
class _WidgetBackground extends StatelessWidget {
  const _WidgetBackground();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topRight,
              radius: 1.22,
              stops: [0, 0.45, 1],
              colors: [
                AppColors.green600,
                AppColors.green800,
                AppColors.green900,
              ],
            ),
          ),
        ),
        Positioned(top: -60, right: -60, child: _CornerGlow()),
      ],
    );
  }
}

class _CornerGlow extends StatelessWidget {
  const _CornerGlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          radius: 0.35,
          colors: [
            AppColors.green300.withValues(alpha: 0.25),
            AppColors.green300.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.dateLabel});

  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            color: AppColors.orange500,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          AppStrings.appTitle,
          style: _text(
            AppTypography.titleS,
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 15,
            height: 1,
          ),
        ),
        const Spacer(),
        Text(
          dateLabel,
          style: _text(
            AppTypography.labelS,
            color: Colors.white.withValues(alpha: 0.62),
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _DownloadFooter extends StatelessWidget {
  const _DownloadFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'iPhoneでカロナビ',
            style: _text(
              AppTypography.titleS,
              color: Colors.white,
              fontSize: 14,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            shareDownloadLabel,
            maxLines: 1,
            style: _text(
              AppTypography.labelS,
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _text(
  TextStyle style, {
  Color? color,
  double? fontSize,
  double? height,
  double? letterSpacing,
}) {
  return style.copyWith(
    fontFamily: AppTypography.fontFamily,
    color: color,
    fontSize: fontSize,
    height: height,
    letterSpacing: letterSpacing,
  );
}

/// ウィジェットの HomeCalorieRing と同じ比率。
/// 132 の枠に半径 58・線幅 10・端は丸。12時から反時計回り。
/// 地は白 16%、進みは白。右上（-38°）のオレンジの点は進捗と連動しない。
/// 超過の日は一周をオレンジにし、中に「超過」と出す。
class _ShareGoalRing extends StatelessWidget {
  const _ShareGoalRing({required this.content});

  final ShareCardContent content;

  static const double _frame = 132;
  static const double _stroke = 10;
  static const double _radius = 58;
  static const double _dot = 13;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        final scale = side / _frame;
        final stroke = _stroke * scale;
        final radius = _radius * scale;
        final innerRadius = radius - stroke / 2;
        final safe = innerRadius * math.sqrt2 * 0.86;
        return SizedBox(
          width: side,
          height: side,
          child: CustomPaint(
            painter: _ShareRingPainter(
              progress: content.progress,
              isOverage: content.isOverage,
              radius: radius,
              strokeWidth: stroke,
              dotDiameter: _dot * scale,
            ),
            child: Center(
              child: SizedBox(
                width: safe,
                height: safe,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (content.isOverage)
                        Text(
                          '超過',
                          style: _text(
                            AppTypography.labelM,
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 16,
                            height: 1.1,
                          ),
                        ),
                      Text(
                        content.intakeLabel,
                        maxLines: 1,
                        softWrap: false,
                        style: _text(
                          AppTypography.displayNumber,
                          color: Colors.white,
                          fontSize: 58,
                          height: 1,
                          letterSpacing: -2.32,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '/ ${content.targetLabel} kcal',
                        maxLines: 1,
                        softWrap: false,
                        style: _text(
                          AppTypography.titleS,
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 18,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShareRingPainter extends CustomPainter {
  const _ShareRingPainter({
    required this.progress,
    required this.isOverage,
    required this.radius,
    required this.strokeWidth,
    required this.dotDiameter,
  });

  final double progress;
  final bool isOverage;
  final double radius;
  final double strokeWidth;
  final double dotDiameter;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final paint = Paint()
      ..color = isOverage ? AppColors.orange500 : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (isOverage || progress >= 1) {
      canvas.drawCircle(center, radius, paint);
    } else if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        -2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        paint,
      );
    }

    const dotAngle = 38 * math.pi / 180;
    final dotCenter =
        center +
        Offset(math.cos(dotAngle) * radius, -math.sin(dotAngle) * radius);
    canvas.drawCircle(
      dotCenter,
      dotDiameter / 2,
      Paint()..color = AppColors.orange500,
    );
  }

  @override
  bool shouldRepaint(covariant _ShareRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isOverage != isOverage ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dotDiameter != dotDiameter;
  }
}
