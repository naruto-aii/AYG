import 'package:flutter/material.dart';

/// カロナビ ブランドカラー定義。
///
/// 値は Figma のカラー変数（Color Styles）と 1:1 で対応する。
/// 変更するときは必ず Figma 側を正とすること。
abstract final class AppColors {
  // ---------------------------------------------------------------------
  // プリミティブ（Figma: green / orange / red / cream / neutral）
  // ---------------------------------------------------------------------
  static const Color green900 = Color(0xFF14522F);
  static const Color green800 = Color(0xFF1B5E39);
  static const Color green700 = Color(0xFF2D7448);
  static const Color green600 = Color(0xFF3C875A);
  static const Color green500 = Color(0xFF5AA277);
  static const Color green300 = Color(0xFFA8D0B8);
  static const Color green200 = Color(0xFFC9E4D3);
  static const Color green100 = Color(0xFFDEF6E5);
  static const Color green75 = Color(0xFFDFEDE0);
  static const Color green50 = Color(0xFFEDF7F0);
  static const Color green25 = Color(0xFFF0F7EB);

  static const Color orange700 = Color(0xFFC96A12);
  static const Color orange500 = Color(0xFFF6892B);
  static const Color orange200 = Color(0xFFFBD9B4);
  static const Color orange100 = Color(0xFFFFF6E5);

  static const Color red600 = Color(0xFFD6493B);
  static const Color red500 = Color(0xFFE53624);
  static const Color red100 = Color(0xFFFCE9E4);

  static const Color cream0 = Color(0xFFFFFFFF);
  static const Color cream50 = Color(0xFFFFFDF8);
  static const Color cream100 = Color(0xFFFEF9EE);
  static const Color cream200 = Color(0xFFF7F1E4);

  static const Color neutral900 = Color(0xFF2E3A33);
  static const Color neutral700 = Color(0xFF55635B);
  static const Color neutral500 = Color(0xFF7C8880);
  static const Color neutral300 = Color(0xFFC3CBC5);
  static const Color neutral200 = Color(0xFFE3E8E3);
  static const Color neutral100 = Color(0xFFEFF2EE);

  // ---------------------------------------------------------------------
  // セマンティック（Figma: bg / text / icon / border / accent / macro）
  // ---------------------------------------------------------------------
  static const Color bgPage = cream100;
  static const Color bgSurface = cream0;
  static const Color bgSurfaceAlt = cream50;
  static const Color bgSurfaceSunken = cream200;
  static const Color bgSurfaceGreen = green100;
  static const Color bgSurfaceGreenSoft = green50;
  static const Color bgSurfaceWarning = orange100;
  static const Color bgSurfaceDanger = red100;
  static const Color bgPrimary = green700;
  static const Color bgPrimaryPressed = green800;
  static const Color bgSecondary = neutral100;
  static const Color bgDisabled = neutral100;
  static const Color bgTrack = neutral200;

  static const Color textPrimary = green900;
  static const Color textSecondary = neutral700;
  static const Color textMuted = neutral500;
  static const Color textBrand = green700;
  static const Color textAccent = orange700;
  static const Color textDanger = red600;
  static const Color textOnPrimary = cream0;

  static const Color iconPrimary = green700;
  static const Color iconMuted = neutral500;
  static const Color iconDanger = red500;
  static const Color iconOnPrimary = cream0;

  static const Color borderDefault = neutral200;
  static const Color borderSubtle = neutral100;
  static const Color borderGreenToken = green200;
  static const Color borderFocus = green700;
  static const Color borderDanger = red500;

  // 背景装飾（ログイン画面の葉・波）
  static const Color deco1 = Color(0xFFF1F7F0);
  static const Color deco2 = Color(0xFFE6F2E3);
  static const Color deco3 = Color(0xFFDBEBD9);
  static const Color deco4 = Color(0xFFCFE5D0);

  // ---------------------------------------------------------------------
  // 既存コード互換エイリアス（値は Figma に合わせて更新済み）
  // ---------------------------------------------------------------------
  static const Color primaryGreen = green700;
  static const Color softGreen = green300;
  static const Color accentOrange = orange500;
  static const Color backgroundCream = bgPage;
  static const Color cardWhite = bgSurface;
  static const Color primaryText = textPrimary;
  static const Color secondaryText = textSecondary;
  static const Color border = borderDefault;
  static const Color borderGreen = borderGreenToken;
  static const Color error = textDanger;

  /// アルコール表示用。Figma に対応トークンが無いため暫定で green500 を使う。
  /// TODO(design): Figma 側でアルコール用の色を定義する。
  static const Color accentWine = green500;

  static const Color macroProtein = green700;
  static const Color macroCarb = orange500;
  static const Color macroFat = green500;

  /// Material seed（後方互換）。
  static const Color seed = green700;
  static const Color heroBackground = green50;
}
