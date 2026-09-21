import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// ログイン画面の認証ボタン（Figma: `AuthButton`）。
///
/// 高さ64 / 角丸999（ピル）/ 左に34のマーク / 中央にラベル / 右に chevron。
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.markAssetPath,
    this.markGlyph,
    this.markBackground,
    this.markSize = 34,
    this.glyphSize = 20,
    this.loading = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;

  /// マークの SVG パス（Google / Apple）。
  final String? markAssetPath;

  /// SVG の代わりに使うアイコン。
  final IconData? markGlyph;

  /// マークの下地（Google は白い丸）。null なら下地なし。
  final Color? markBackground;

  final double markSize;
  final double glyphSize;
  final bool loading;

  static const double _height = 64;
  static const double _sidePadding = 18;

  Widget _buildMark() {
    final Widget inner;
    if (loading) {
      inner = SizedBox(
        width: glyphSize,
        height: glyphSize,
        child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
      );
    } else if (markAssetPath != null) {
      inner = SvgPicture.asset(
        markAssetPath!,
        width: glyphSize,
        height: glyphSize,
        fit: BoxFit.contain,
      );
    } else if (markGlyph != null) {
      inner = Icon(markGlyph, size: glyphSize, color: foreground);
    } else {
      inner = const SizedBox.shrink();
    }

    return Container(
      width: markSize,
      height: markSize,
      alignment: Alignment.center,
      decoration: markBackground == null
          ? null
          : BoxDecoration(color: markBackground, shape: BoxShape.circle),
      child: inner,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(_height / 2),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: _height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
              child: Row(
                children: [
                  _buildMark(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.buttonL.copyWith(
                          color: foreground,
                        ),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: glyphSize,
                    color: foreground,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma 実測値に沿った Google / Apple のプリセット。
abstract final class AuthButtonStyles {
  static Color get googleBackground => AppColors.bgPrimary;
  static Color get googleForeground => AppColors.textOnPrimary;
  static Color get appleBackground => AppColors.bgSecondary;
  static Color get appleForeground => AppColors.textPrimary;
}
