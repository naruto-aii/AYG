import 'package:flutter/material.dart';

import 'app_colors.dart';

/// カロナビ タイポグラフィ。
///
/// 値は Figma の Text Styles と 1:1 で対応する（Zen Maru Gothic）。
/// lineHeight は Figma の % を Flutter の height（倍率）に変換した値。
abstract final class AppTypography {
  /// pubspec.yaml で登録したフォントファミリー名。
  static const String fontFamily = 'ZenMaruGothic';

  static const FontWeight _regular = FontWeight.w400;
  static const FontWeight _medium = FontWeight.w500;
  static const FontWeight _bold = FontWeight.w700;

  // --- Figma Text Styles ------------------------------------------------
  /// Display/Number — Bold 64 / 100% / -2%
  static const TextStyle displayNumber = TextStyle(
    fontSize: 64,
    fontWeight: _bold,
    height: 1.0,
    letterSpacing: -1.28,
    color: AppColors.textPrimary,
  );

  /// Heading/XL — Bold 34 / 130% / -1%
  static const TextStyle headingXl = TextStyle(
    fontSize: 34,
    fontWeight: _bold,
    height: 1.3,
    letterSpacing: -0.34,
    color: AppColors.textPrimary,
  );

  /// Heading/L — Bold 28 / 130% / -1%
  static const TextStyle headingL = TextStyle(
    fontSize: 28,
    fontWeight: _bold,
    height: 1.3,
    letterSpacing: -0.28,
    color: AppColors.textPrimary,
  );

  /// Heading/M — Bold 24 / 140% / -0.5%
  static const TextStyle headingM = TextStyle(
    fontSize: 24,
    fontWeight: _bold,
    height: 1.4,
    letterSpacing: -0.12,
    color: AppColors.textPrimary,
  );

  /// Heading/S — Bold 20 / 140%
  static const TextStyle headingS = TextStyle(
    fontSize: 20,
    fontWeight: _bold,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  /// Heading/Tagline — Bold 20 / 150%
  static const TextStyle tagline = TextStyle(
    fontSize: 20,
    fontWeight: _bold,
    height: 1.5,
    color: AppColors.textBrand,
  );

  /// Title/L — Bold 18 / 150%
  static const TextStyle titleL = TextStyle(
    fontSize: 18,
    fontWeight: _bold,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  /// Title/M — Bold 16 / 150%
  static const TextStyle titleM = TextStyle(
    fontSize: 16,
    fontWeight: _bold,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  /// Title/S — Bold 15 / 150%
  static const TextStyle titleS = TextStyle(
    fontSize: 15,
    fontWeight: _bold,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  /// Body/L — Regular 16 / 170%
  static const TextStyle bodyL = TextStyle(
    fontSize: 16,
    fontWeight: _regular,
    height: 1.7,
    color: AppColors.textSecondary,
  );

  /// Body/M — Regular 15 / 170%
  static const TextStyle bodyM = TextStyle(
    fontSize: 15,
    fontWeight: _regular,
    height: 1.7,
    color: AppColors.textSecondary,
  );

  /// Body/S — Regular 13 / 160%
  static const TextStyle bodyS = TextStyle(
    fontSize: 13,
    fontWeight: _regular,
    height: 1.6,
    color: AppColors.textSecondary,
  );

  /// Label/M — Medium 13 / 140%
  static const TextStyle labelM = TextStyle(
    fontSize: 13,
    fontWeight: _medium,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  /// Label/S — Medium 12 / 140%
  static const TextStyle labelS = TextStyle(
    fontSize: 12,
    fontWeight: _medium,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  /// Caption — Regular 11 / 140%
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: _regular,
    height: 1.4,
    color: AppColors.textMuted,
  );

  /// Button/L — Bold 17 / 120%
  static const TextStyle buttonL = TextStyle(
    fontSize: 17,
    fontWeight: _bold,
    height: 1.2,
  );

  /// Button/M — Bold 15 / 120%
  static const TextStyle buttonM = TextStyle(
    fontSize: 15,
    fontWeight: _bold,
    height: 1.2,
  );

  /// Value/XL — Bold 34 / 110% / -1%
  static const TextStyle valueXl = TextStyle(
    fontSize: 34,
    fontWeight: _bold,
    height: 1.1,
    letterSpacing: -0.34,
    color: AppColors.textPrimary,
  );

  /// Value/L — Bold 22 / 120% / -0.5%
  static const TextStyle valueL = TextStyle(
    fontSize: 22,
    fontWeight: _bold,
    height: 1.2,
    letterSpacing: -0.11,
    color: AppColors.textPrimary,
  );

  /// Value/M — Bold 17 / 130%
  static const TextStyle valueM = TextStyle(
    fontSize: 17,
    fontWeight: _bold,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  /// Link — Medium 14 / 150%
  static const TextStyle link = TextStyle(
    fontSize: 14,
    fontWeight: _medium,
    height: 1.5,
    color: AppColors.textBrand,
  );

  // --- Material TextTheme への割り当て ----------------------------------
  static const TextTheme textTheme = TextTheme(
    displayLarge: displayNumber,
    displayMedium: headingXl,
    displaySmall: valueXl,
    headlineLarge: headingL,
    headlineMedium: headingM,
    headlineSmall: headingS,
    titleLarge: headingS,
    titleMedium: titleM,
    titleSmall: titleS,
    bodyLarge: bodyL,
    bodyMedium: bodyM,
    bodySmall: bodyS,
    labelLarge: labelM,
    labelMedium: labelS,
    labelSmall: caption,
  );

  // --- 既存コード互換ヘルパー -------------------------------------------
  static TextStyle heroValue(BuildContext context) =>
      displayNumber.copyWith(color: AppColors.textPrimary);

  static TextStyle heroLabel(BuildContext context) => labelM;

  static TextStyle sectionTitle(BuildContext context) => titleL;

  static TextStyle macroLabel(BuildContext context) => labelS;

  static TextStyle macroValue(BuildContext context) => valueM;

  /// ロゴ横のプロダクト名「カロナビ」。
  static TextStyle brandTitle(
    BuildContext context, {
    required double markSize,
  }) {
    final fontSize = (markSize * 0.78).clamp(18.0, 40.0);
    return headingM.copyWith(
      color: AppColors.textBrand,
      fontSize: fontSize,
      height: 1.1,
      letterSpacing: -fontSize * 0.025,
    );
  }
}
