import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../theme/app_spacing.dart';
import '../../utils/macro_display.dart';
import '../../utils/nutrition_format.dart';

/// タンパク質 / 脂質 / 炭水化物を Wrap で折り返し表示する。
class CompactMacroDisplay extends StatelessWidget {
  const CompactMacroDisplay({
    super.key,
    this.kcal,
    this.proteinG,
    this.fatG,
    this.carbG,
    this.textStyle,
    this.showKcal = true,
    this.fractionDigits = 0,
  });

  final double? kcal;
  final double? proteinG;
  final double? fatG;
  final double? carbG;
  final TextStyle? textStyle;
  final bool showKcal;
  final int fractionDigits;

  @override
  Widget build(BuildContext context) {
    final style = textStyle ?? Theme.of(context).textTheme.bodySmall;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xxs,
      children: [
        if (showKcal && kcal != null)
          Text(
            '${formatNullableNutrient(kcal, fractionDigits: fractionDigits)} kcal',
            style: style,
          ),
        if (proteinG != null)
          Text(
            formatMacroGramsLine(
              AppStrings.macroProtein,
              proteinG,
              fractionDigits: fractionDigits,
            ),
            style: style,
          ),
        if (fatG != null)
          Text(
            formatMacroGramsLine(
              AppStrings.macroFat,
              fatG,
              fractionDigits: fractionDigits,
            ),
            style: style,
          ),
        if (carbG != null)
          Text(
            formatMacroGramsLine(
              AppStrings.macroCarb,
              carbG,
              fractionDigits: fractionDigits,
            ),
            style: style,
          ),
      ],
    );
  }
}

/// 縦並びのマクロ表示（履歴 subtitle など）。
class VerticalMacroDisplay extends StatelessWidget {
  const VerticalMacroDisplay({
    super.key,
    this.kcal,
    this.proteinG,
    this.fatG,
    this.carbG,
    this.textStyle,
    this.showKcal = true,
    this.fractionDigits = 0,
    this.leading,
    this.trailing,
  });

  final double? kcal;
  final double? proteinG;
  final double? fatG;
  final double? carbG;
  final TextStyle? textStyle;
  final bool showKcal;
  final int fractionDigits;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = textStyle ?? Theme.of(context).textTheme.bodySmall;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(height: AppSpacing.xxs),
        ],
        if (showKcal && kcal != null)
          Text(
            '${formatNullableNutrient(kcal, fractionDigits: fractionDigits)} kcal',
            style: style,
          ),
        if (proteinG != null)
          Text(
            formatMacroGramsLine(
              AppStrings.macroProtein,
              proteinG,
              fractionDigits: fractionDigits,
            ),
            style: style,
          ),
        if (fatG != null)
          Text(
            formatMacroGramsLine(
              AppStrings.macroFat,
              fatG,
              fractionDigits: fractionDigits,
            ),
            style: style,
          ),
        if (carbG != null)
          Text(
            formatMacroGramsLine(
              AppStrings.macroCarb,
              carbG,
              fractionDigits: fractionDigits,
            ),
            style: style,
          ),
        if (trailing != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          trailing!,
        ],
      ],
    );
  }
}
