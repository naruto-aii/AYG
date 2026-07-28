import 'package:flutter/material.dart';

import 'app_colors.dart';

/// カロナビ タイポグラフィ。
abstract final class AppTypography {
  static TextTheme textTheme = const TextTheme(
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      color: AppColors.primaryText,
      height: 1.2,
    ),
    headlineLarge: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: AppColors.primaryText,
      height: 1.25,
    ),
    headlineMedium: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: AppColors.primaryText,
      height: 1.3,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.primaryText,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.primaryText,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.primaryText,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.primaryText,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.primaryText,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.secondaryText,
      height: 1.4,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.secondaryText,
    ),
  );

  static TextStyle heroValue(BuildContext context) {
    return Theme.of(context).textTheme.displaySmall!.copyWith(
      color: AppColors.primaryGreen,
      fontWeight: FontWeight.w700,
    );
  }

  static TextStyle heroLabel(BuildContext context) {
    return Theme.of(
      context,
    ).textTheme.titleMedium!.copyWith(color: AppColors.secondaryText);
  }

  static TextStyle sectionTitle(BuildContext context) {
    return Theme.of(
      context,
    ).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w600);
  }

  static TextStyle macroLabel(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge!;
  }

  static TextStyle macroValue(BuildContext context) {
    return Theme.of(
      context,
    ).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700);
  }
}
