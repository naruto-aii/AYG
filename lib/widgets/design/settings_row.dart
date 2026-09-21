import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import 'design_icon.dart';
import 'icon_circle.dart';

/// Figma: SettingsRow（State=Default / Danger）。
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.danger = false,
    this.showChevron = true,
    this.trailing,
    this.leading,
  });

  /// assets/icons の SVG パス。
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;

  /// 遷移先がない行では false にして矢印を消す。
  final bool showChevron;

  /// 矢印の代わりに置くもの（「…」メニューなど）。
  final Widget? trailing;

  /// アイコンの代わりに置くもの（チェックなど）。
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final tone = danger ? IconCircleTone.danger : IconCircleTone.green;
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled || !showChevron || trailing != null ? 1 : 0.5,
      child: Material(
        color: danger ? AppColors.bgSurfaceDanger : AppColors.bgSurface,
        borderRadius: AppRadius.card,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.card,
          child: Container(
            height: 80,
            padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
            child: Row(
              children: [
                leading ??
                    IconCircle(
                      tone: tone,
                      size: 44,
                      child: AppIcon(
                        icon,
                        size: 24,
                        color: IconCircle.foregroundOf(tone),
                      ),
                    ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleM.copyWith(
                          color: danger
                              ? AppColors.textDanger
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyS.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 4),
                  trailing!,
                ] else if (showChevron) ...[
                  const SizedBox(width: 8),
                  DesignIcon(
                    Symbols.chevron_right_rounded,
                    size: 24,
                    color: danger ? AppColors.iconDanger : AppColors.iconMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
