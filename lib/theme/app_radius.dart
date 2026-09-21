import 'package:flutter/material.dart';

/// 角丸定数。値は Figma の radius 変数と 1:1 で対応する。
abstract final class AppRadius {
  /// Figma: --radius-sm
  static const double sm = 12;

  /// Figma: --radius-md
  static const double md = 16;

  /// Figma: --radius-lg
  static const double lg = 20;

  /// Figma: --radius-xl
  static const double xl = 24;

  /// Figma: --radius-full
  static const double full = 999;

  static const BorderRadius cardLarge = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius button = BorderRadius.all(Radius.circular(full));
  static const BorderRadius input = BorderRadius.all(Radius.circular(md));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(full));
  static const BorderRadius bottomNav = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}
