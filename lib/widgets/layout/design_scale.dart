import 'dart:math' as math;

import '../../theme/app_breakpoints.dart';

/// 設計キャンバス（390×844）を画面に収める倍率。
///
/// 上限は iPhone の実測（最大でも約 1.2）より上なので、スマホの見た目は変わらない。
/// iPad の縦長画面だけ、高さいっぱいに引き伸ばさない。
double designCanvasScale({
  required double maxWidth,
  required double maxHeight,
  double designWidth = 390,
  double designHeight = 844,
  double maxScale = 1.5,
}) {
  if (maxWidth <= 0 || maxHeight <= 0) {
    return 1;
  }
  final contain = math.min(maxWidth / designWidth, maxHeight / designHeight);
  if (!contain.isFinite) {
    return maxScale;
  }
  return math.min(contain, maxScale);
}

/// [DesignScreen] の倍率。幅で頭打ちし、iPad で縦が足りないときはさらに下げる。
///
/// iPhone（短い辺が [AppBreakpoints.tabletShortestSide] 未満）は幅だけの倍率のまま。
double designScreenScale({
  required double maxWidth,
  required double maxHeight,
  required double shortestSide,
  double designWidth = 390,
  double maxScale = 1.5,
  double minTabletDesignHeight = 640,
}) {
  if (maxWidth <= 0) {
    return 1;
  }
  final raw = math.min(maxWidth / designWidth, maxScale);
  if (raw <= 0 || !raw.isFinite) {
    return 1;
  }
  if (shortestSide < AppBreakpoints.tabletShortestSide ||
      !maxHeight.isFinite ||
      maxHeight <= 0) {
    return raw;
  }
  if (maxHeight / raw < minTabletDesignHeight) {
    return math.min(raw, maxHeight / minTabletDesignHeight);
  }
  return raw;
}
