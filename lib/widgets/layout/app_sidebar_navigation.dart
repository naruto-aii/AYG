import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../brand/app_logo.dart';

class AppSidebarNavigation extends StatelessWidget {
  const AppSidebarNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _destinations = [
    (
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: AppStrings.navHome,
    ),
    (
      icon: Icons.restaurant_outlined,
      selectedIcon: Icons.restaurant,
      label: AppStrings.navFood,
    ),
    (
      icon: Icons.fitness_center_outlined,
      selectedIcon: Icons.fitness_center,
      label: AppStrings.navWorkout,
    ),
    (
      icon: Icons.monitor_weight_outlined,
      selectedIcon: Icons.monitor_weight,
      label: AppStrings.navWeight,
    ),
    (
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: AppStrings.navSettings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardWhite,
      child: SizedBox(
        width: AppBreakpoints.sidebarWidth,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: AppLogo(height: 28),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  children: [
                    for (var i = 0; i < _destinations.length; i++)
                      _SidebarTile(
                        icon: _destinations[i].icon,
                        selectedIcon: _destinations[i].selectedIcon,
                        label: _destinations[i].label,
                        selected: selectedIndex == i,
                        onTap: () => onDestinationSelected(i),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryGreen : AppColors.secondaryText;
    final background = selected ? AppColors.heroBackground : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(selected ? selectedIcon : icon, size: 22, color: color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? AppColors.primaryText : color,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
