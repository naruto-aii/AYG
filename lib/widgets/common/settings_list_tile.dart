import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../brand/calonavi_icon.dart';
import 'app_card.dart';

/// 設定画面用の角丸リストタイル。
class SettingsListTile extends StatelessWidget {
  const SettingsListTile({
    super.key,
    required this.icon,
    this.iconName,
    required this.title,
    this.subtitle,
    this.onTap,
    this.enabled = true,
    this.destructive = false,
    this.asCard = false,
  });

  final IconData icon;
  final String? iconName;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final bool destructive;
  final bool asCard;

  @override
  Widget build(BuildContext context) {
    final accent = destructive
        ? AppColors.error
        : (enabled ? AppColors.iconPrimary : AppColors.iconMuted);

    final tile = ListTile(
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: destructive
              ? AppColors.bgSurfaceDanger
              : AppColors.bgSurfaceGreenSoft,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: iconName == null
            ? Icon(icon, color: accent, size: 20)
            : CalonaviIcon(iconName!, size: 20, color: accent),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontFamilyFallback: AppTypography.fontFamilyFallback,
          color: destructive ? AppColors.error : AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
          height: 1.5,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
      trailing: enabled && onTap != null
          ? const Icon(Icons.chevron_right, color: AppColors.iconMuted)
          : null,
      onTap: onTap,
    );

    if (!asCard) {
      return tile;
    }

    return AppCard(
      padding: EdgeInsets.zero,
      elevated: false,
      child: tile,
    );
  }
}
