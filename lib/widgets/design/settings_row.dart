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
    this.tag,
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

  /// 名前の横に置く短い印。検索結果の「AIによる推定」など。
  final String? tag;

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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleM.copyWith(
                                color: danger
                                    ? AppColors.textDanger
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (tag != null) ...[
                            const SizedBox(width: 6),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.green50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                child: Text(
                                  tag!,
                                  maxLines: 1,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textBrand,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
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
