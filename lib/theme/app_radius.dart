import 'package:flutter/material.dart';

/// 角丸定数。
abstract final class AppRadius {
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 28;

  static const BorderRadius cardLarge = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius button = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius input = BorderRadius.all(Radius.circular(md));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(999));
  static const BorderRadius bottomNav = BorderRadius.vertical(
    top: Radius.circular(lg),
  );
}
