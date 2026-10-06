import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../services/share_card_content.dart';
import '../../services/share_links.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import '../brand/app_brand_mark.dart';

/// 共有用のカード。白と緑、アプリアイコン、入手先を載せる。
class ShareCardView extends StatelessWidget {
  const ShareCardView({super.key, required this.content});

  final ShareCardContent content;

  @override
  Widget build(BuildContext context) {
    final story = content.format == ShareCardFormat.story;
    final headlineSize = story ? 64.0 : 42.0;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: ColoredBox(
        color: AppColors.bgPage,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned(
                right: story ? -30 : -46,
                top: story ? -10 : -36,
                child: Container(
                  width: story ? 220 : 150,
                  height: story ? 220 : 150,
                  decoration: const BoxDecoration(
                    color: AppColors.green100,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  22,
                  story ? 36 : 12,
                  22,
                  story ? 16 : 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _BrandLockup(),
                    SizedBox(height: story ? 28 : 6),
                    Text(
                      content.dateLabel,
                      style: _text(AppTypography.caption),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      content.eyebrow,
                      style: _text(
                        AppTypography.titleM,
                        color: AppColors.textBrand,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _figure(child: _headline(headlineSize)),
                    const SizedBox(height: 6),
                    Text(
                      content.detail,
                      style: _text(
                        AppTypography.bodyM,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (content.extra != null) ...[
                      const SizedBox(height: 2),
                      Text(content.extra!, style: _text(AppTypography.bodyS)),
                    ],
                    if (content.macros != null) ...[
                      SizedBox(height: story ? 22 : 8),
                      _MacroBar(balance: content.macros!),
                    ],
                    if (content.trend != null) ...[
                      SizedBox(height: story ? 22 : 12),
                      _figure(
                        child: SizedBox(
                          height: story ? 120 : 56,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _TrendPainter(content.trend!),
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (story) ...[
                      Text(
                        AppStrings.loginTagline,
                        style: _text(
                          AppTypography.bodyM,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const _DownloadFooter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headline(double size) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            content.headline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _text(AppTypography.displayNumber, fontSize: size),
          ),
        ),
        if (content.unit.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(
            content.unit,
            style: _text(
              AppTypography.headingS,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _figure({required Widget child}) {
    if (content.privacy != WeightPrivacy.blurred) {
      return child;
    }
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: child,
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppBrandMark(size: 28),
        const SizedBox(width: 8),
        Text(
          AppStrings.appTitle,
          style: AppTypography.headingS.copyWith(
            fontFamily: AppTypography.fontFamily,
            color: AppColors.textPrimary,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'iPhoneでカロナビ',
            style: AppTypography.titleM.copyWith(
              fontFamily: AppTypography.fontFamily,
              color: AppColors.textOnPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            shareDownloadLabel,
            style: AppTypography.caption.copyWith(
              fontFamily: AppTypography.fontFamily,
              color: AppColors.green100,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({required this.balance});

  final ShareMacroBalance balance;

  @override
  Widget build(BuildContext context) {
    final slices = [
      (balance.protein, AppColors.macroProtein, 'たんぱく質'),
      (balance.fat, AppColors.macroFat, '脂質'),
      (balance.carb, AppColors.macroCarb, '炭水化物'),
    ].where((slice) => slice.$1 > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                for (final slice in slices)
                  Expanded(
                    flex: slice.$1,
                    child: ColoredBox(color: slice.$2),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final slice in [
              (balance.protein, 'たんぱく質'),
              (balance.fat, '脂質'),
              (balance.carb, '炭水化物'),
            ])
              Expanded(
                child: Text(
                  '${slice.$2}\n${slice.$1}%',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    fontFamily: AppTypography.fontFamily,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) {
      return;
    }
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final span = (maxValue - minValue).abs() < 0.01 ? 1.0 : maxValue - minValue;
    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          size.width * i / (values.length - 1),
          size.height -
              6 -
              ((values[i] - minValue) / span) * (size.height - 12),
        ),
    ];
    final fill = Path()..moveTo(points.first.dx, size.height);
    for (final point in points) {
      fill.lineTo(point.dx, point.dy);
    }
    fill
      ..lineTo(points.last.dx, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = AppColors.green100);
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.green700
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

TextStyle _text(TextStyle style, {Color? color, double? fontSize}) {
  return style.copyWith(
    fontFamily: AppTypography.fontFamily,
    color: color,
    fontSize: fontSize,
  );
}
