import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import 'design_icon.dart';
import 'icon_circle.dart';

/// Figma: StatItem（目標 / 摂取 / 運動）。
class StatItem extends StatelessWidget {
  const StatItem({
    super.key,
    required this.label,
    required this.value,
    this.unit = 'kcal',
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.labelM.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.valueL,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: AppTypography.labelS.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Figma: MacroBar（PFC の 1 項目）。
class MacroBar extends StatelessWidget {
  const MacroBar({
    super.key,
    required this.icon,
    required this.label,
    required this.remainingG,
    required this.targetG,
    required this.progress,
    required this.color,
  });

  final String icon;
  final String label;
  final String remainingG;
  final String targetG;

  /// 0.0〜1.0。
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconCircle(
              size: 26,
              child: AppIcon(
                icon,
                size: 24,
                color: IconCircle.foregroundOf(IconCircleTone.green),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelM.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.bgTrack,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'あと',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                remainingG,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.valueM,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'g',
              style: AppTypography.labelS.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '目標 $targetG g',
          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// Figma: QuickAddCard。
class QuickAddCard extends StatelessWidget {
  const QuickAddCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgSurface,
      borderRadius: AppRadius.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Container(
          height: 64,
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              IconCircle(
                size: 30,
                child: AppIcon(
                  icon,
                  size: 24,
                  color: IconCircle.foregroundOf(IconCircleTone.green),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: AppTypography.labelM.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const DesignIcon(
                Symbols.chevron_right_rounded,
                size: 16,
                color: AppColors.iconMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma: SectionHeader（アイコン＋見出し＋すべて見る）。
class DesignSectionHeader extends StatelessWidget {
  const DesignSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          AppIcon(icon, size: 22, color: AppColors.iconPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleL,
            ),
          ),
          const SizedBox(width: 8),
          if (actionLabel != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel!,
                      style: AppTypography.labelM.copyWith(
                        color: AppColors.textBrand,
                      ),
                    ),
                    const DesignIcon(
                      Symbols.chevron_right_rounded,
                      size: 18,
                      color: AppColors.iconPrimary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Figma: ListRow（時刻・名前・数値の 1 行）。
class DesignListRow extends StatelessWidget {
  const DesignListRow({
    super.key,
    required this.icon,
    required this.time,
    required this.title,
    required this.value,
    this.unit = 'kcal',
    this.onTap,
    this.onLongPress,
  });

  final String icon;
  final String time;
  final String title;
  final String value;
  final String unit;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
        child: Row(
          children: [
            IconCircle(
              size: 34,
              child: AppIcon(
                icon,
                size: 24,
                color: IconCircle.foregroundOf(IconCircleTone.green),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              time,
              style: AppTypography.labelS.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyM.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(value, style: AppTypography.valueM),
            const SizedBox(width: 4),
            Text(
              unit,
              style: AppTypography.labelS.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(width: 10),
            const DesignIcon(
              Symbols.chevron_right_rounded,
              size: 18,
              color: AppColors.iconMuted,
            ),
          ],
        ),
      ),
    );
  }
}
