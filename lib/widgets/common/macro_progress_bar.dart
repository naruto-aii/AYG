import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class MacroProgressBar extends StatelessWidget {
  const MacroProgressBar({
    super.key,
    required this.label,
    required this.intakeG,
    required this.targetG,
    required this.color,
    this.compact = false,
  });

  final String label;
  final double intakeG;
  final double targetG;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final progress = targetG > 0 ? (intakeG / targetG).clamp(0.0, 1.0) : 0.0;
    final remaining = (targetG - intakeG).clamp(0, double.infinity);
    final barSpacing = compact ? 2.0 : AppSpacing.xxs;
    final barHeight = compact ? 8.0 : 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppTypography.macroLabel(context)),
            const Spacer(),
            Text(
              '残り ${remaining.toStringAsFixed(0)} g',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        SizedBox(height: barSpacing),
        ClipRRect(
          borderRadius: AppRadius.chip,
          child: LinearProgressIndicator(
            value: progress,
            minHeight: barHeight,
            backgroundColor: color.withValues(alpha: 0.15),
            color: color,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${intakeG.toStringAsFixed(0)} / ${targetG.toStringAsFixed(0)} g',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.secondaryText),
          ),
        ],
      ],
    );
  }
}
