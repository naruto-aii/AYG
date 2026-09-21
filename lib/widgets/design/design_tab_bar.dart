import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';

/// Figma: TabBar の 1 件分。
class DesignTabItem {
  const DesignTabItem({required this.icon, required this.label});

  /// assets/icons の SVG パス。
  final String icon;

  /// 読み上げ用のラベル（Figma では文字は出さない）。
  final String label;
}

/// Figma: 画面下部のオレンジのタブバー。
///
/// 選択中のタブだけがバーから丸く浮き上がり、バー側はその形に切り抜かれる。
class DesignTabBar extends StatelessWidget {
  const DesignTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.items = defaultItems,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<DesignTabItem> items;

  /// Figma の並び（ホームが中央）。
  static const List<DesignTabItem> defaultItems = [
    DesignTabItem(icon: AppIcons.meal, label: '食事'),
    DesignTabItem(icon: AppIcons.exercise, label: '運動'),
    DesignTabItem(icon: AppIcons.home, label: 'ホーム'),
    DesignTabItem(icon: AppIcons.scale, label: '体重'),
    DesignTabItem(icon: AppIcons.settings, label: '設定'),
  ];

  /// Figma のバー高さ。下 35pt がホームインジケータの逃げ。
  static const double barHeight = 80;

  /// 1 つめのアイコン中心と、以降の間隔。
  static const double _firstCenterX = 39;
  static const double _stepX = 78;
  static const double _iconSize = 32;
  static const double _iconTop = 13;
  static const double _raisedRadius = 26;
  static const double _raisedTop = 3;

  static double _centerXOf(int index) => _firstCenterX + _stepX * index;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Figma のバーは 80pt の中にホームインジケータ領域まで含んでいる。
    // 端末側の逃げがそれより大きいときだけ足りない分を伸ばす。
    final height = barHeight + math.max(0.0, bottomInset - 34);
    final activeCenterX = _centerXOf(selectedIndex);

    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TabBarShapePainter(activeCenterX: activeCenterX),
            ),
          ),
          Positioned(
            left: activeCenterX - _raisedRadius,
            top: _raisedTop,
            child: Container(
              width: _raisedRadius * 2,
              height: _raisedRadius * 2,
              decoration: BoxDecoration(
                color: AppColors.green700,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.green700.withValues(alpha: 0.55),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          for (var i = 0; i < items.length; i++)
            Positioned(
              left: _centerXOf(i) - _stepX / 2,
              top: 0,
              width: _stepX,
              height: _iconTop + _iconSize + 6,
              child: Semantics(
                label: items[i].label,
                selected: i == selectedIndex,
                button: true,
                child: InkResponse(
                  onTap: () => onSelected(i),
                  radius: 32,
                  child: Padding(
                    padding: const EdgeInsets.only(top: _iconTop),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: AppIcon(
                        items[i].icon,
                        size: _iconSize,
                        color: AppColors.cream0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// オレンジのバーから、選択中のタブの下に丸いくぼみを抜く。
class _TabBarShapePainter extends CustomPainter {
  const _TabBarShapePainter({required this.activeCenterX});

  final double activeCenterX;

  /// Figma の notch（124×62）をそのまま写したもの。
  static Path _notchPath() {
    return Path()
      ..moveTo(0, 0)
      ..cubicTo(17.67, 0, 32, 14.33, 32, 32)
      ..lineTo(32, 37)
      ..cubicTo(32, 50.81, 43.19, 62, 57, 62)
      ..lineTo(67, 62)
      ..cubicTo(80.81, 62, 92, 50.81, 92, 37)
      ..lineTo(92, 32)
      ..cubicTo(92, 14.33, 106.33, 0, 124, 0)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bar = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Offset.zero & size,
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8),
        ),
      );
    final notch = _notchPath().shift(Offset(activeCenterX - 62, 0));

    canvas.drawPath(
      Path.combine(PathOperation.difference, bar, notch),
      Paint()..color = AppColors.orange500,
    );
  }

  @override
  bool shouldRepaint(_TabBarShapePainter oldDelegate) =>
      oldDelegate.activeCenterX != activeCenterX;
}
