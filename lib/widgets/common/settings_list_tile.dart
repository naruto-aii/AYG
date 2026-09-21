import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'app_card.dart';

/// 設定画面用の角丸リストタイル。
class SettingsListTile extends StatelessWidget {
  const SettingsListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.enabled = true,
    this.destructive = false,
    this.asCard = false,
  });

  final IconData icon;
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
        child: Icon(icon, color: accent, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: destructive ? AppColors.error : AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
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
