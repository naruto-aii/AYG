import 'package:flutter/material.dart';

import '../../constants/official_food_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// 出典を1行に収める。収まらないときだけ短い文面にする。
class OfficialFoodAttributionLine extends StatelessWidget {
  const OfficialFoodAttributionLine({super.key, this.style});

  final TextStyle? style;

  static String textForWidth(double maxWidth, TextStyle style) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return OfficialFoodCopy.compactAttribution;
    }
    final painter = TextPainter(
      text: TextSpan(text: OfficialFoodCopy.fullAttribution, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    if (painter.didExceedMaxLines) {
      return OfficialFoodCopy.compactAttribution;
    }
    return OfficialFoodCopy.fullAttribution;
  }

  @override
  Widget build(BuildContext context) {
    final resolved =
        style ?? AppTypography.caption.copyWith(color: AppColors.textMuted);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Text(
          textForWidth(constraints.maxWidth, resolved),
          style: resolved,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
