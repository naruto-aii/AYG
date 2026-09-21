import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Figma「icon一覧」から書き出した線アイコン。
class CalonaviIcon extends StatelessWidget {
  const CalonaviIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color,
  });

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/$name.png',
      width: size,
      height: size,
      color: color ?? AppColors.iconPrimary,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.medium,
    );
  }
}
