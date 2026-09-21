import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import 'design_icon.dart';

/// Figma: TabItem の 1 件分。
class DesignTabItem {
  const DesignTabItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Figma: TabBar。ラベルは常時表示。
class DesignTabBar extends StatelessWidget {
  const DesignTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<DesignTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Figma の標準 5 タブ。
  static const List<DesignTabItem> defaultItems = [
    DesignTabItem(icon: Symbols.home_rounded, label: 'ホーム'),
    DesignTabItem(icon: Symbols.restaurant_rounded, label: '食事'),
    DesignTabItem(icon: Symbols.directions_run_rounded, label: '運動'),
    DesignTabItem(icon: Symbols.monitor_weight_rounded, label: '体重'),
    DesignTabItem(icon: Symbols.settings_rounded, label: '設定'),
  ];

  @override
  Widget build(BuildContext context) {
    // Figma の pb-20 は端末のホームインジケータ領域にあたる。
    final bottomInset = math.max(MediaQuery.paddingOf(context).bottom, 20.0);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: AppRadius.bottomNav,
      ),
      padding: EdgeInsets.only(top: 6, left: 8, right: 8, bottom: bottomInset),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < items.length; i++)
            _TabItemView(
              item: items[i],
              active: i == selectedIndex,
              onTap: () => onSelected(i),
            ),
        ],
      ),
    );
  }
}

class _TabItemView extends StatelessWidget {
  const _TabItemView({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final DesignTabItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.iconPrimary : AppColors.iconMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: 72,
        height: 54,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DesignIcon(item.icon, size: 26, color: color),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: AppTypography.labelS.copyWith(
                color: active ? AppColors.textBrand : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
