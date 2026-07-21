import 'package:flutter/material.dart';

/// アプリ共通のテキストスタイル。
abstract final class AppTextStyles {
  static TextStyle? sectionTitle(BuildContext context) {
    return Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
  }

  static TextStyle? heroLabel(BuildContext context, Color color) {
    return Theme.of(context).textTheme.titleMedium?.copyWith(color: color);
  }

  static TextStyle? heroValue(BuildContext context, Color color) {
    return Theme.of(context).textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.bold,
      color: color,
    );
  }

  static TextStyle? macroLabel(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  static TextStyle? macroValue(BuildContext context) {
    return Theme.of(
      context,
    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold);
  }

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
