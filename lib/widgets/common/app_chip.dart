import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onTap == null ? null : (_) => onTap!(),
      avatar: icon == null ? null : Icon(icon, size: 18),
      showCheckmark: false,
      selectedColor: AppColors.softGreen,
      backgroundColor: AppColors.cardWhite,
      side: BorderSide(
        color: selected ? AppColors.primaryGreen : AppColors.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.chip),
      labelStyle: TextStyle(
        color: selected ? AppColors.primaryGreen : AppColors.primaryText,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}
