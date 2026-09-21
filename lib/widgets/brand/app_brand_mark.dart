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

  /// Figma の BrandMark/Tight は 66 x 67.1。わずかに縦長。
  static const double heightRatio = 67.1 / 66;

  /// マークの幅（論理ピクセル）。高さは縦横比から決まる。
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      BrandAssets.brandMarkSvg,
      width: size,
      height: size * heightRatio,
      fit: BoxFit.fill,
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
