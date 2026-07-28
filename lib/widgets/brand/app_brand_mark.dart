import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import 'brand_assets.dart';

/// 暫定アプリアイコン / ブランドマーク（SVG 差し替え可能）。
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({
    super.key,
    this.size = 72,
    this.borderRadius = AppRadius.lg,
  });

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SvgPicture.asset(
        BrandAssets.iconPlaceholderSvg,
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
      child: Text(
        AppStrings.provisionalAppIconText,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
