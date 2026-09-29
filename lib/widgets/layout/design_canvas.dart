import 'package:flutter/material.dart';

/// Figma の設計キャンバス（390×844）を、縦横比を保ったまま画面サイズに
/// 合わせて拡大縮小する土台。
///
/// 中身は常に 390×844 の座標系で組めばよい。画面が大きくなっても小さくなっても
/// 位置関係は一切変わらないので、配置バランスは Figma と同じになる。
///
/// [background] だけは画面全体を埋める倍率で敷くため、端に隙間ができない。
/// 縦横比が近いスマホでは中身との差は 1% 未満なので、ずれて見えることはない。
class DesignCanvas extends StatelessWidget {
  const DesignCanvas({super.key, required this.child, this.background});

  static const double designWidth = 390;
  static const double designHeight = 844;

  /// 設計キャンバス上に置く中身。
  final Widget child;

  /// 画面全体を埋める背景。
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (background != null)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: designWidth,
              height: designHeight,
              child: background,
            ),
          ),
        Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: designWidth,
              height: designHeight,
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}
