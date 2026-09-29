import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_breakpoints.dart';
import 'app_responsive.dart';

/// 本文を中央寄せし、最大幅を制限する（Desktop幅のみ）。
class AppContentConstraint extends StatelessWidget {
  const AppContentConstraint({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.contentMaxWidth,
    this.expandVertically = false,
  });

  final Widget child;
  final double maxWidth;
  final bool expandVertically;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopLayout(context)) {
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, maxWidth);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: expandVertically ? constraints.maxHeight : null,
            child: child,
          ),
        );
      },
    );
  }
}
