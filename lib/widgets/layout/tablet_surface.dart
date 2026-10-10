import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_breakpoints.dart';

/// 短い辺が iPad の regular 幅か。iPhone の縦横では false。
bool isTabletLayout(Size size) {
  return size.shortestSide >= AppBreakpoints.tabletShortestSide;
}

/// Slide Over や、タブバー（390pt）が入りきらない細い Split View。
///
/// iPhone SE（320×568）と iPhone mini（375×812）は含めない。
bool isCompactTabletWindow(Size size) {
  if (size.width >= 390 || size.height < 700) {
    return false;
  }
  if (size.width < 360) {
    return true;
  }
  return size.height >= 830;
}

/// iPad のダイアログ・シート・スナックバーを、端まで伸ばさない幅に収める。
///
/// iPhone では呼ばない。ここを通るとダイアログの最大幅が変わり、
/// スマホの見た目と黄金画像がずれる。
ThemeData tabletSurfaceTheme(
  ThemeData theme,
  Size size,
  EdgeInsets viewInsets,
) {
  final maxDialogHeight = math.max(
    240.0,
    size.height - viewInsets.vertical - 48,
  );
  return theme.copyWith(
    dialogTheme: theme.dialogTheme.copyWith(
      constraints: BoxConstraints(
        minWidth: 280,
        maxWidth: 560,
        maxHeight: maxDialogHeight,
      ),
    ),
    bottomSheetTheme: theme.bottomSheetTheme.copyWith(
      constraints: const BoxConstraints(maxWidth: AppBreakpoints.formMaxWidth),
    ),
    snackBarTheme: theme.snackBarTheme.copyWith(width: 480),
  );
}

/// iPad の本文を読みやすい幅で中央に置く。iPhone はそのまま返す。
class TabletReadableWidth extends StatelessWidget {
  const TabletReadableWidth({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.formMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (!isTabletLayout(MediaQuery.sizeOf(context))) {
      return child;
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
