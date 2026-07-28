import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import 'brand_assets.dart';

/// 暫定ブランドマーク（装飾SVGのみ。文字は [AppLogo] の Text で表示）。
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({
    super.key,
    this.size = 32,
    this.borderRadius = AppRadius.md,
  });

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SvgPicture.asset(
        BrandAssets.brandMarkSvg,
        width: size,
        height: size,
        placeholderBuilder: (_) =>
            _FallbackMark(size: size, borderRadius: borderRadius),
      ),
    );
  }
}

class _FallbackMark extends StatelessWidget {
  const _FallbackMark({required this.size, required this.borderRadius});

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.eco_outlined, color: Colors.white, size: size * 0.52),
    );
  }
}
