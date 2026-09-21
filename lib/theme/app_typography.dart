import 'package:flutter/material.dart';

import 'app_colors.dart';

/// カロナビ タイポグラフィ。Figma「Zen Maru Gothic」準拠。
abstract final class AppTypography {
  static const String fontFamily = 'Zen Maru Gothic';

  static const TextTheme textTheme = TextTheme(
    displaySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1.1,
      letterSpacing: -0.34,
    ),
    headlineLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1.3,
      letterSpacing: -0.28,
    ),
    headlineMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1.4,
      letterSpacing: -0.12,
    ),
    headlineSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1.4,
    ),
    titleLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1.5,
    ),
    titleMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1.5,
    ),
    titleSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1.5,
    ),
    bodyLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
      height: 1.7,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
      height: 1.7,
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.textMuted,
      height: 1.6,
    ),
    labelLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
      height: 1.4,
    ),
    labelMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.textMuted,
      height: 1.4,
    ),
    labelSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: AppColors.textMuted,
      height: 1.4,
    ),
  );

  static TextStyle heroValue(BuildContext context) {
    return Theme.of(context).textTheme.displaySmall!.copyWith(
      color: AppColors.textPrimary,
      fontSize: 36,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
  }

  static TextStyle heroLabel(BuildContext context) {
    return Theme.of(context).textTheme.titleSmall!.copyWith(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w500,
    );
  }

  static TextStyle sectionTitle(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium!;
  }

  static TextStyle macroLabel(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge!.copyWith(
      color: AppColors.textSecondary,
    );
  }

  static TextStyle macroValue(BuildContext context) {
    return Theme.of(context).textTheme.titleSmall!;
  }

  static TextStyle buttonLarge(BuildContext context) {
    return const TextStyle(
      fontFamily: fontFamily,
      fontSize: 17,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );
  }

  /// ロゴ横のプロダクト名「カロナビ」。
  static TextStyle brandTitle(
    BuildContext context, {
    required double markSize,
  }) {
    final fontSize = (markSize * 0.42).clamp(20.0, 34.0);
    return Theme.of(context).textTheme.headlineSmall!.copyWith(
      color: AppColors.textBrand,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.1,
      letterSpacing: 0,
    );
  }
}
