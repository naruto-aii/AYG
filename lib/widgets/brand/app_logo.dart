import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'app_brand_mark.dart';

/// 暫定ロゴ: ブランドマーク + 「カロナビ」テキスト。
///
/// 将来は [BrandAssets.fullLogoSvg] への差し替えも可能な構造。
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.markSize,
    this.height,
    this.vertical = false,
    this.textStyle,
  });

  /// ブランドマークの一辺（px）。
  final double? markSize;

  /// 後方互換: [markSize] 未指定時の目安高さ。
  final double? height;

  /// true のときマーク上・テキスト下（ログイン向け）。
  final bool vertical;

  final TextStyle? textStyle;

  double get _markSize => markSize ?? ((height ?? 40) * 0.72);

  TextStyle _titleStyle(BuildContext context) {
    return textStyle ?? AppTypography.brandTitle(context, markSize: _markSize);
  }

  @override
  Widget build(BuildContext context) {
    final title = Text(
      AppStrings.appTitle,
      style: _titleStyle(context),
      maxLines: 1,
      softWrap: false,
    );
    final mark = AppBrandMark(
      size: _markSize,
      borderRadius: vertical ? AppSpacing.sm : AppSpacing.xs + 2,
    );

    if (vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          SizedBox(height: AppSpacing.sm),
          title,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        mark,
        SizedBox(width: AppSpacing.sm),
        Flexible(child: title),
      ],
    );
  }
}
