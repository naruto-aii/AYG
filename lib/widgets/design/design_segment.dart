import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';

/// Figma: Segment（State=Selected / Default）を横に並べたもの。
class DesignSegmentGroup<T> extends StatelessWidget {
  const DesignSegmentGroup({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
    this.spacing = 8,
    this.height = 48,
  });

  final List<T> values;
  final String Function(T value) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;
  final double spacing;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          Expanded(
            child: _Segment(
              label: labelOf(values[i]),
              selected: values[i] == selected,
              height: height,
              onTap: () => onChanged(values[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.height,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.bgSurfaceGreen : AppColors.bgSecondary,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: SizedBox(
          height: height,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: selected
                  ? AppTypography.titleS.copyWith(color: AppColors.textBrand)
                  : AppTypography.bodyM.copyWith(color: AppColors.textMuted),
            ),
          ),
        ),
      ),
    );
  }
}
