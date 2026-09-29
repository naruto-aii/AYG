import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../theme/app_typography.dart';
import 'app_brand_mark.dart';

/// カロナビ ロゴ（ブランドマーク＋「カロナビ」）。
///
/// Figma の `Logo/Horizontal`（マーク40 / 文字20 / 間隔8）と
/// ログイン画面の縦組み（マーク130 / 文字40 / 間隔8）に対応する。
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.markSize,
    this.height,
    this.vertical = false,
    this.titleSize,
    this.gap,
    this.textStyle,
  });

  /// ブランドマークの一辺。
  final double? markSize;

  /// 後方互換: [markSize] 未指定時の目安高さ。
  final double? height;

  /// true のときマーク上・テキスト下（ログイン向け）。
  final bool vertical;

  /// 「カロナビ」の文字サイズ。未指定なら組み方から自動算出。
  final double? titleSize;

  /// マークと文字の間隔。未指定なら 8。
  final double? gap;

  final TextStyle? textStyle;

  double get _markSize => markSize ?? ((height ?? 40) * 0.72);

  /// Figma 実測比: 横組み 20/40 = 0.5、縦組み 40/130 ≒ 0.31。
  double get _titleSize => titleSize ?? (_markSize * (vertical ? 0.31 : 0.5));

  double get _gap => gap ?? 8;

  TextStyle _titleStyle(BuildContext context) {
    return textStyle ??
        AppTypography.brandTitle(context, markSize: _markSize).copyWith(
          fontSize: _titleSize,
          letterSpacing: -_titleSize * 0.025,
        );
  }

  @override
  Widget build(BuildContext context) {
    final title = Text(
      AppStrings.appTitle,
      style: _titleStyle(context),
      maxLines: 1,
      softWrap: false,
    );
    final mark = AppBrandMark(size: _markSize);

    if (vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [mark, SizedBox(height: _gap), title],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [mark, SizedBox(width: _gap), Flexible(child: title)],
    );
  }
}
