import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 柔らかい影定義（黒く硬い影は使わない）。
abstract final class AppShadows {
  /// Figma: shadow/card — #2D7448 12% / offset (0,4) / blur 16。
  static List<BoxShadow> get card => [
    BoxShadow(
      color: AppColors.green700.withValues(alpha: 0.07),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get elevated => [
    BoxShadow(
      color: AppColors.green700.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
      spreadRadius: -2,
    ),
  ];

  static List<BoxShadow> get subtle => [
    BoxShadow(
      color: AppColors.green900.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];
}
