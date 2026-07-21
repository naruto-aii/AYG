import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

class TodayProgressBar extends StatelessWidget {
  const TodayProgressBar({
    super.key,
    required this.intakeKcal,
    required this.targetKcal,
    required this.progressValue,
  });

  final double intakeKcal;
  final double targetKcal;
  final double progressValue;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '今日の進捗',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${intakeKcal.toStringAsFixed(0)} / ${targetKcal.toStringAsFixed(0)} kcal',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.xs),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
