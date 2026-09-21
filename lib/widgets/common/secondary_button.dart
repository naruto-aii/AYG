import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.trailingChevron = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool trailingChevron;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.bgSurface,
        foregroundColor: AppColors.textBrand,
        minimumSize: const Size.fromHeight(64),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22),
            const SizedBox(width: 10),
          ],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          if (trailingChevron) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 22),
          ],
        ],
      ),
    );

    if (!expand) {
      return button;
    }

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: button,
      ),
    );
  }
}
