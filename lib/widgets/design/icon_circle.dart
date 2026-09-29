import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';

/// Figma: IconCircle（Tone=Green / Danger / Orange / Neutral）。
enum IconCircleTone { green, danger, orange, neutral }

class IconCircle extends StatelessWidget {
  const IconCircle({
    super.key,
    required this.child,
    this.tone = IconCircleTone.green,
    this.size = 44,
  });

  /// 中に置くアイコン。色は [foregroundOf] を使って呼び出し側で指定する。
  final Widget child;
  final IconCircleTone tone;
  final double size;

  static Color backgroundOf(IconCircleTone tone) {
    switch (tone) {
      case IconCircleTone.green:
        return AppColors.bgSurfaceGreen;
      case IconCircleTone.danger:
        return AppColors.bgSurfaceDanger;
      case IconCircleTone.orange:
        return AppColors.orange500;
      case IconCircleTone.neutral:
        return AppColors.bgSecondary;
    }
  }

  static Color foregroundOf(IconCircleTone tone) {
    switch (tone) {
      case IconCircleTone.green:
        return AppColors.iconPrimary;
      case IconCircleTone.danger:
        return AppColors.iconDanger;
      case IconCircleTone.orange:
        return AppColors.iconOnPrimary;
      case IconCircleTone.neutral:
        return AppColors.iconMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundOf(tone),
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}
