import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../theme/app_colors.dart';
import '../brand/calonavi_icon.dart';

/// Figma のオレンジ下タブ。並びは 食事・運動・ホーム・体重・設定。
class CalonaviTabBar extends StatelessWidget {
  const CalonaviTabBar({
    super.key,
    required this.screenIndex,
    required this.onSelectScreen,
  });

  final int screenIndex;
  final ValueChanged<int> onSelectScreen;

  static const barToScreen = [1, 2, 0, 3, 4];

  static const _items = [
    (icon: 'meal', label: AppStrings.navFood),
    (icon: 'exercise', label: AppStrings.navWorkout),
    (icon: 'home', label: AppStrings.navHome),
    (icon: 'scale', label: AppStrings.navWeight),
    (icon: 'settings', label: AppStrings.navSettings),
  ];

  @override
  Widget build(BuildContext context) {
    final barIndex = barToScreen.indexOf(screenIndex);

    return ColoredBox(
      color: AppColors.bgPage,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(child: ColoredBox(color: AppColors.accentOrange)),
              Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: _TabItem(
                        icon: _items[i].icon,
                        label: _items[i].label,
                        selected: i == barIndex,
                        onTap: () => onSelectScreen(barToScreen[i]),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 80,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (selected)
              Positioned(
                top: 4,
                child: Container(
                  width: 72,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(36),
                    ),
                  ),
                ),
              ),
            if (selected)
              Positioned(
                top: 8,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppColors.bgPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            CalonaviIcon(
              icon,
              size: 26,
              color: AppColors.iconOnPrimary,
            ),
            Offstage(child: Text(label)),
          ],
        ),
      ),
    );
  }
}
