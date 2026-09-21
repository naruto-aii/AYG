import 'package:flutter/material.dart';

/// 角丸定数。Figma はボタン・入力が完全なカプセル。
abstract final class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius cardLarge = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius button = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius input = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius bottomNav = BorderRadius.vertical(
    top: Radius.circular(0),
  );
}
