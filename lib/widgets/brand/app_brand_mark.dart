import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_colors.dart';
import 'brand_assets.dart';

/// カロナビのブランドマーク（円＋葉＋オレンジの点）。
///
/// Figma の `BrandMark` コンポーネントをそのまま書き出したもの。
/// 背景は透過なので、置いた場所の地色がそのまま見える。
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key, this.size = 32});

  /// マークの一辺（論理ピクセル）。
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      BrandAssets.brandMarkSvg,
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => _FallbackMark(size: size),
    );
  }
}

/// SVG 読み込み前／失敗時の代替表示。
class _FallbackMark extends StatelessWidget {
  const _FallbackMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Icon(
        Icons.eco_outlined,
        color: AppColors.primaryGreen,
        size: size * 0.8,
      ),
    );
  }
}
