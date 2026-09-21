import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';

/// Figma: GoalCard（State=Selected / Default）。
class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    this.onTap,
    this.height = 140,
  });

  /// 32pt のアイコン。
  final Widget icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.bgSurfaceGreenSoft : AppColors.bgSurface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.borderFocus : AppColors.borderSubtle,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 32, height: 32, child: Center(child: icon)),
              const SizedBox(height: 8),
              Text(
                title,
                style: AppTypography.titleM.copyWith(
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
