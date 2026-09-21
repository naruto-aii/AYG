import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import 'design_icon.dart';
import 'icon_circle.dart';

/// Figma: WarnBanner。
class WarnBanner extends StatelessWidget {
  const WarnBanner({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceWarning,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconCircle(
            tone: IconCircleTone.orange,
            size: 32,
            child: DesignIcon(
              Symbols.priority_high_rounded,
              size: 24,
              color: IconCircle.foregroundOf(IconCircleTone.orange),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.titleM.copyWith(
                    color: AppColors.textAccent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: AppTypography.bodyS.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
