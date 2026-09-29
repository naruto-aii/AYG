import 'package:flutter/widgets.dart';
export 'package:material_symbols_icons/symbols.dart' show Symbols;

/// Figma の `Icon` コンポーネントと同じ字形で描くアイコン。
///
/// Figma 側は Material Symbols Rounded を FILL 0 / GRAD 0 で使っているので、
/// 同じ可変軸を指定して字形を合わせる。アイコン名は `Symbols.xxx_rounded`。
class DesignIcon extends StatelessWidget {
  const DesignIcon(this.icon, {super.key, this.size = 24, this.color});

  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size, color: color, fill: 0, grade: 0);
  }
}
