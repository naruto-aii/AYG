import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'brand_assets.dart';

/// ログイン画面の背景装飾（波・アーク・葉）。
///
/// Figma の 390×844 を基準に描かれたベクター。
/// 画面サイズが変わっても左右上下が切れないよう [BoxFit.cover] で敷く。
/// 背景色そのものは [Scaffold] 側で指定する（この SVG は透過）。
class LoginBackground extends StatelessWidget {
  const LoginBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: SvgPicture.asset(
          BrandAssets.loginBackgroundSvg,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          placeholderBuilder: (_) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
