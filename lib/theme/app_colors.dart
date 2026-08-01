import 'package:flutter/material.dart';

/// カロナビ ブランドカラー定義。
abstract final class AppColors {
  static const Color primaryGreen = Color(0xFF4CAF7D);
  static const Color softGreen = Color(0xFFA8D5A2);
  static const Color accentOrange = Color(0xFFFFB366);
  static const Color accentWine = Color(0xFF9B6B9E);
  static const Color backgroundCream = Color(0xFFFFF9F1);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color primaryText = Color(0xFF3D3A36);
  static const Color secondaryText = Color(0xFF7A7570);
  static const Color border = Color(0xFFE8E2D8);
  static const Color borderGreen = Color(0xFFD4EAD4);
  static const Color error = Color(0xFFD64545);

  static const Color macroProtein = primaryGreen;
  static const Color macroCarb = accentOrange;
  static const Color macroFat = Color(0xFF8BC4A8);

  /// Material seed（後方互換）。
  static const Color seed = primaryGreen;
  static const Color heroBackground = Color(0xFFEAF6EE);
}
