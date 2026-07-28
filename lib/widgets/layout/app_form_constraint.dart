import 'package:flutter/material.dart';

import '../../theme/app_breakpoints.dart';
import 'app_content_constraint.dart';

/// 入力フォーム向けの狭い最大幅制限。
class AppFormConstraint extends StatelessWidget {
  const AppFormConstraint({
    super.key,
    required this.child,
    this.expandVertically = false,
  });

  final Widget child;
  final bool expandVertically;

  @override
  Widget build(BuildContext context) {
    return AppContentConstraint(
      maxWidth: AppBreakpoints.formMaxWidth,
      expandVertically: expandVertically,
      child: child,
    );
  }
}
