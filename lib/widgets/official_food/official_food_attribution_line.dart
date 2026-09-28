import 'package:flutter/material.dart';

import '../../constants/official_food_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// 出典の表示。1行に収まるときは全文、収まらないときは短い文面。
/// どちらも省略記号では切らない。短い文面は2行まで折り返す。
class OfficialFoodAttributionLine extends StatelessWidget {
  const OfficialFoodAttributionLine({super.key, this.style});

  final TextStyle? style;

  static bool fits({
    required String text,
    required double maxWidth,
    required TextStyle style,
    required TextScaler textScaler,
    required int maxLines,
  }) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return false;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: textScaler,
      maxLines: maxLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return !painter.didExceedMaxLines;
  }

  static String textForWidth(
    double maxWidth,
    TextStyle style, {
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    if (fits(
      text: OfficialFoodCopy.fullAttribution,
      maxWidth: maxWidth,
      style: style,
      textScaler: textScaler,
      maxLines: 1,
    )) {
      return OfficialFoodCopy.fullAttribution;
    }
    return OfficialFoodCopy.compactAttribution;
  }

  @override
  Widget build(BuildContext context) {
    final resolved =
        style ?? AppTypography.caption.copyWith(color: AppColors.textMuted);
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final text = textForWidth(
          constraints.maxWidth,
          resolved,
          textScaler: textScaler,
        );
        final fitsInTwoLines = fits(
          text: text,
          maxWidth: constraints.maxWidth,
          style: resolved,
          textScaler: textScaler,
          maxLines: 2,
        );
        return Text(
          text,
          style: resolved,
          softWrap: true,
          maxLines: fitsInTwoLines ? 2 : null,
        );
      },
    );
  }
}
