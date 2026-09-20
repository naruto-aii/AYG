import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Web プレビュー専用。アプリ本体の機能制限を利用者に見せる。
class WebPreviewNotice extends StatelessWidget {
  const WebPreviewNotice({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (compact) {
      return ColoredBox(
        color: AppColors.heroBackground,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Text(
            AppStrings.webPreviewUnavailableSummary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.primaryText,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Text(
          AppStrings.webPreviewTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppStrings.webPreviewUnavailableIntro,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppStrings.webPreviewUnavailableList,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppStrings.webPreviewUseApp,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }
}
