import 'package:flutter/material.dart';

import 'app_typography.dart';

/// アプリ共通のテキストスタイル（後方互換ラッパー）。
abstract final class AppTextStyles {
  static TextStyle? sectionTitle(BuildContext context) =>
      AppTypography.sectionTitle(context);

  static TextStyle? heroLabel(BuildContext context, Color color) {
    return AppTypography.heroLabel(context).copyWith(color: color);
  }

  static TextStyle? heroValue(BuildContext context, Color color) {
    return AppTypography.heroValue(context).copyWith(color: color);
  }

  static TextStyle? macroLabel(BuildContext context) =>
      AppTypography.macroLabel(context);

  static TextStyle? macroValue(BuildContext context) =>
      AppTypography.macroValue(context);

  static TextStyle? historyDateHeader(BuildContext context) {
    return Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold);
  }

  static TextStyle? historySectionHeader(BuildContext context) {
    return Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}
