import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import 'design_icon.dart';

/// Figma: Chip を並べた期間切り替え。
class DesignChipGroup<T> extends StatelessWidget {
  const DesignChipGroup({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final String Function(T value) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        children: [
          for (final value in values)
            Expanded(
              child: _Chip(
                label: labelOf(value),
                selected: value == selected,
                onTap: () => onChanged(value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.bgPrimary : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelM.copyWith(
              color: selected
                  ? AppColors.textOnPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma: WeightRow。
class WeightRow extends StatelessWidget {
  const WeightRow({
    super.key,
    required this.dateLabel,
    required this.weight,
    required this.fromHealth,
    this.onTap,
    this.onMore,
  });

  final String dateLabel;
  final String weight;

  /// true なら Health 由来、false なら手入力。
  final bool fromHealth;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyM,
              ),
            ),
            const SizedBox(width: 10),
            Text(weight, style: AppTypography.valueM),
            const SizedBox(width: 4),
            Text(
              'kg',
              style: AppTypography.labelS.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(width: 10),
            if (fromHealth)
              const AppIcon(
                AppIcons.heart,
                size: 16,
                color: AppColors.iconMuted,
              )
            else
              const AppIcon(AppIcons.pen, size: 16, color: AppColors.iconMuted),
            const SizedBox(width: 4),
            Text(
              fromHealth ? 'Health' : '手入力',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(width: 10),
            InkResponse(
              onTap: onMore,
              radius: 20,
              child: const DesignIcon(
                Symbols.more_horiz_rounded,
                size: 18,
                color: AppColors.iconMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Figma: グラフカードの折れ線（面塗り＋点、最後の点だけ白抜き）。
class WeightChart extends StatelessWidget {
  const WeightChart({super.key, required this.values, this.height = 120});

  /// 古い順の体重。2 点未満のときは何も描かない。
  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _WeightChartPainter(values: values),
      ),
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  const _WeightChartPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      return;
    }

    const inset = 8.0;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final span = (maxValue - minValue).abs() < 0.1 ? 1.0 : maxValue - minValue;

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = inset + (size.width - inset * 2) * i / (values.length - 1);
      final y =
          inset +
          (size.height - inset * 2) * (1 - (values[i] - minValue) / span);
      points.add(Offset(x, y));
    }

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }

    final area = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(
      area,
      Paint()..color = AppColors.green700.withValues(alpha: 0.10),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.green700
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    final dot = Paint()..color = AppColors.green700;
    for (final point in points.take(points.length - 1)) {
      canvas.drawCircle(point, 3.5, dot);
    }

    // 最新の点だけ白抜きで強調する。
    canvas.drawCircle(points.last, 6, Paint()..color = AppColors.bgSurface);
    canvas.drawCircle(
      points.last,
      6,
      Paint()
        ..color = AppColors.green700
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_WeightChartPainter oldDelegate) =>
      !listEquals(oldDelegate.values, values);

  static bool listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
