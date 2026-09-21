import 'package:flutter/material.dart';

import 'app_colors.dart';

/// カロナビ タイポグラフィ。Figma「Zen Maru Gothic」準拠。
/// 日本語は行間を狭くしすぎない（潰れて文字化けに見えるため）。
abstract final class AppTypography {
  static const String fontFamily = 'Zen Maru Gothic';
  static const List<String> fontFamilyFallback = [
    'Hiragino Maru Gothic ProN',
    'Hiragino Sans',
    'YuGothic',
    'Noto Sans CJK JP',
  ];

  static const TextStyle _base = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
  );

  static TextTheme get textTheme => TextTheme(
    displaySmall: _base.copyWith(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1.1,
      letterSpacing: -0.34,
    ),
    headlineLarge: _base.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1.3,
      letterSpacing: -0.28,
    ),
    headlineMedium: _base.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1.4,
      letterSpacing: -0.12,
    ),
    headlineSmall: _base.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1.4,
    ),
    titleLarge: _base.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1.5,
    ),
    titleMedium: _base.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1.5,
    ),
    titleSmall: _base.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1.5,
    ),
    bodyLarge: _base.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
      height: 1.7,
    ),
    bodyMedium: _base.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
      height: 1.7,
    ),
    bodySmall: _base.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.textMuted,
      height: 1.6,
    ),
    labelLarge: _base.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
      height: 1.4,
    ),
    labelMedium: _base.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.textMuted,
      height: 1.4,
    ),
    labelSmall: _base.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: AppColors.textMuted,
      height: 1.4,
    ),
  );

  static TextStyle heroValue(BuildContext context) {
    return _base.copyWith(
      color: AppColors.textPrimary,
      fontSize: 36,
      fontWeight: FontWeight.w700,
      height: 1.0,
    );
  }

  static TextStyle heroLabel(BuildContext context) {
    return _base.copyWith(
      color: AppColors.textMuted,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.5,
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
    return _base.copyWith(
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
    final fontSize = markSize >= 100 ? 28.0 : 20.0;
    return _base.copyWith(
      color: AppColors.textBrand,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: 0,
    );
  }
}
