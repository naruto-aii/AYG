import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import 'design_icon.dart';

/// Figma: MiniField（小さなラベル＋白い入力枠）。
class MiniField extends StatelessWidget {
  const MiniField({
    super.key,
    required this.label,
    required this.child,
    this.unit,
    this.onTap,
  });

  final String label;
  final Widget child;
  final String? unit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Expanded(child: child),
          if (unit != null) ...[
            const SizedBox(width: 4),
            Text(
              unit!,
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 16,
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (onTap == null)
          box
        else
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: box,
          ),
      ],
    );
  }
}

/// Figma: FormTab の 1 件分。
class FormTabItem {
  const FormTabItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Figma: formtabs（入力方法の切り替え）。
class FormTabBar extends StatelessWidget {
  const FormTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<FormTabItem> items;

  /// どれも選ばれていない状態は -1。
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _FormTab(
                item: items[i],
                active: i == selectedIndex,
                onTap: () => onSelected(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _FormTab extends StatelessWidget {
  const _FormTab({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final FormTabItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.iconPrimary : AppColors.iconMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DesignIcon(item.icon, size: 20, color: color),
            const SizedBox(height: 4),
            // 幅が足りないときだけ横に縮める。高さは固定。
            SizedBox(
              height: 16,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  softWrap: false,
                  style: AppTypography.caption.copyWith(
                    color: active ? AppColors.textBrand : AppColors.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: active ? AppColors.bgPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
