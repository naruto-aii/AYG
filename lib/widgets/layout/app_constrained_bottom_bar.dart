import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import 'app_form_constraint.dart';
import 'app_responsive.dart';

/// 画面下部の保存ボタン等を読みやすい幅に制限する（Desktop幅のみ）。
class AppConstrainedBottomBar extends StatelessWidget {
  const AppConstrainedBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: isDesktopLayout(context) ? AppFormConstraint(child: child) : child,
    );

    return SafeArea(child: content);
  }
}
