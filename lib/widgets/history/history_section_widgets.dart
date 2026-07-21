import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class HistoryDateHeader extends StatelessWidget {
  const HistoryDateHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(label, style: AppTextStyles.historyDateHeader(context)),
    );
  }
}

class HistorySectionHeader extends StatelessWidget {
  const HistorySectionHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xs),
      child: Text(label, style: AppTextStyles.historySectionHeader(context)),
    );
  }
}

class HistoryEmptySlotMessage extends StatelessWidget {
  const HistoryEmptySlotMessage({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        bottom: AppSpacing.md,
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
