import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'brand_assets.dart';

/// 暫定ロゴ（SVG Asset へ差し替え可能）。
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 40, this.color});

  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      BrandAssets.logoSvg,
      height: height,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
      placeholderBuilder: (_) => _FallbackWordmark(height: height),
    );
  }
}

class _FallbackWordmark extends StatelessWidget {
  const _FallbackWordmark({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppStrings.appTitle,
      style: AppTypography.textTheme.headlineMedium!.copyWith(
        color: AppColors.primaryGreen,
        fontSize: height * 0.65,
      ),
    );
  }
}
