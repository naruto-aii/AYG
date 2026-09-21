import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Figma の設計幅（390pt）で組んだ画面を、どの端末でも同じ配置バランスで
/// 見せるための土台。
///
/// 中身は常に 390pt 幅の座標系で書けばよい。実際の描画では
/// `画面幅 / 390` を全要素へ一律に掛けるため、余白・文字・角丸の比率は
/// Figma と完全に一致する。縦は倍率を掛けたうえでスクロールさせるので、
/// 本文が 844pt を超えていても切れない。
///
/// タブレットのように極端に広い画面では [maxScale] で頭打ちにし、
/// 中央寄せする。背景はページ色で端まで塗るので左右に帯は出ない。
class DesignScreen extends StatelessWidget {
  const DesignScreen({
    super.key,
    required this.child,
    this.background,
    this.backgroundColor,
    this.maxScale = 1.5,
  });

  /// Figma と同じ 390pt 座標系で組んだ中身。
  final Widget child;

  /// 設計キャンバス上に敷く背景（省略時は [backgroundColor] の単色）。
  final Widget? background;

  /// 画面全体の地の色。
  final Color? backgroundColor;

  /// 拡大率の上限。
  final double maxScale;

  /// 設計幅。
  static const double designWidth = 390;

  /// 現在の拡大率。設計座標 1pt が実機の何論理ピクセルにあたるか。
  static double scaleOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_DesignScaleScope>()
            ?.scale ??
        1;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    // ColoredBox ではなく Material にしておくと、中の ListTile や InkWell の
    // 波紋がこの面に描かれる。
    return Material(
      color: backgroundColor ?? AppColors.bgPage,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = math.min(constraints.maxWidth / designWidth, maxScale);
          final innerHeight = constraints.maxHeight / scale;

          return Stack(
            fit: StackFit.expand,
            children: [
              ?background,
              Center(
                child: SizedBox(
                  width: designWidth * scale,
                  height: constraints.maxHeight,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: _DesignScaleScope(
                      scale: scale,
                      child: MediaQuery(
                        // 端末のセーフエリアは実寸。設計座標に戻して渡す。
                        data: mediaQuery.copyWith(
                          size: Size(designWidth, innerHeight),
                          padding: mediaQuery.padding / scale,
                          viewPadding: mediaQuery.viewPadding / scale,
                          viewInsets: mediaQuery.viewInsets / scale,
                        ),
                        child: SizedBox(
                          width: designWidth,
                          height: innerHeight,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DesignScaleScope extends InheritedWidget {
  const _DesignScaleScope({required this.scale, required super.child});

  final double scale;

  @override
  bool updateShouldNotify(_DesignScaleScope oldWidget) =>
      oldWidget.scale != scale;
}
