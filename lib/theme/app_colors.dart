import 'package:flutter/material.dart';

/// カロナビ ブランドカラー。Figma「カロナビ Color Styles」準拠。
abstract final class AppColors {
  static const Color bgPage = Color(0xFFFEF9EE);
  static const Color bgSurface = Color(0xFFFFFFFF);
  static const Color bgSurfaceAlt = Color(0xFFFFFDF8);
  static const Color bgSurfaceSunken = Color(0xFFF7F1E4);
  static const Color bgSurfaceGreen = Color(0xFFDEF6E5);
  static const Color bgSurfaceGreenSoft = Color(0xFFEDF7F0);
  static const Color bgSurfaceWarning = Color(0xFFFFF6E5);
  static const Color bgSurfaceDanger = Color(0xFFFCE9E4);
  static const Color bgPrimary = Color(0xFF2D7448);
  static const Color bgPrimaryPressed = Color(0xFF1B5E39);
  static const Color bgSecondary = Color(0xFFEFF2EE);
  static const Color bgTrack = Color(0xFFE3E8E3);
  static const Color bgDisabled = Color(0xFFEFF2EE);

  static const Color textPrimary = Color(0xFF14522F);
  static const Color textSecondary = Color(0xFF55635B);
  static const Color textMuted = Color(0xFF7C8880);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textBrand = Color(0xFF2D7448);
  static const Color textDanger = Color(0xFFD6493B);
  static const Color textAccent = Color(0xFFC96A12);

  static const Color borderDefault = Color(0xFFE3E8E3);
  static const Color borderSubtle = Color(0xFFEFF2EE);
  static const Color borderGreen = Color(0xFFC9E4D3);
  static const Color borderFocus = Color(0xFF2D7448);
  static const Color borderDanger = Color(0xFFE53624);

  static const Color iconPrimary = Color(0xFF2D7448);
  static const Color iconMuted = Color(0xFF7C8880);
  static const Color iconOnPrimary = Color(0xFFFFFFFF);
  static const Color iconDanger = Color(0xFFE53624);

  static const Color accentOrange = Color(0xFFF6892B);
  static const Color accentOrangeSoft = Color(0xFFFBD9B4);
  static const Color accentWine = Color(0xFF9B6B9E);

  static const Color macroProtein = Color(0xFF2D7448);
  static const Color macroFat = Color(0xFF5AA277);
  static const Color macroCarb = Color(0xFFF6892B);

  /// 後方互換エイリアス。
  static const Color primaryGreen = bgPrimary;
  static const Color softGreen = bgSurfaceGreen;
  static const Color backgroundCream = bgPage;
  static const Color cardWhite = bgSurface;
  static const Color primaryText = textPrimary;
  static const Color secondaryText = textSecondary;
  static const Color border = borderDefault;
  static const Color error = textDanger;
  static const Color seed = bgPrimary;
  static const Color heroBackground = bgSurfaceGreenSoft;
}
