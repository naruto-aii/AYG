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
/// タブを変えると、切り欠きと丸が隣のタブまで滑らかに移動する。
class DesignTabBar extends StatefulWidget {
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

  /// タブを移るときの所要時間。
  static const Duration moveDuration = Duration(milliseconds: 280);

  static double centerXOf(int index) => _firstCenterX + _stepX * index;

  @override
  State<DesignTabBar> createState() => _DesignTabBarState();
}

class _DesignTabBarState extends State<DesignTabBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _centerX;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: DesignTabBar.moveDuration,
    );
    final start = DesignTabBar.centerXOf(widget.selectedIndex);
    _centerX = AlwaysStoppedAnimation<double>(start);
  }

  @override
  void didUpdateWidget(DesignTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex == widget.selectedIndex) {
      return;
    }
    // 今いる位置から次のタブへ。連打されても途中から繋がる。
    _centerX = Tween<double>(
      begin: _centerX.value,
      end: DesignTabBar.centerXOf(widget.selectedIndex),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Figma のバーは 80pt の中にホームインジケータ領域まで含んでいる。
    // 端末側の逃げがそれより大きいときだけ足りない分を伸ばす。
    final height = DesignTabBar.barHeight + math.max(0.0, bottomInset - 34);

    return SizedBox(
      height: height,
      child: AnimatedBuilder(
        animation: _centerX,
        builder: (context, child) {
          final activeCenterX = _centerX.value;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _TabBarShapePainter(activeCenterX: activeCenterX),
                ),
              ),
              Positioned(
                left: activeCenterX - DesignTabBar._raisedRadius,
                top: DesignTabBar._raisedTop,
                child: Container(
                  width: DesignTabBar._raisedRadius * 2,
                  height: DesignTabBar._raisedRadius * 2,
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
              ?child,
            ],
          );
        },
        // アイコンは動かないので、毎フレーム作り直さない。
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < items.length; i++)
              Positioned(
                left: DesignTabBar.centerXOf(i) - DesignTabBar._stepX / 2,
                top: 0,
                width: DesignTabBar._stepX,
                height: DesignTabBar._iconTop + DesignTabBar._iconSize + 6,
                child: Semantics(
                  label: items[i].label,
                  selected: i == widget.selectedIndex,
                  button: true,
                  child: InkResponse(
                    onTap: () => widget.onSelected(i),
                    radius: 32,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: DesignTabBar._iconTop,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: AppIcon(
                          items[i].icon,
                          size: DesignTabBar._iconSize,
                          color: AppColors.cream0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
