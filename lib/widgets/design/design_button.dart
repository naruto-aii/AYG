import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import 'design_icon.dart';

/// Figma: Button（Style=Primary / Secondary / Outline / Danger）。
enum DesignButtonStyle { primary, secondary, outline, danger }

class DesignButton extends StatelessWidget {
  const DesignButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style = DesignButtonStyle.primary,
    this.showTrailingIcon = true,
    this.leading,
    this.loading = false,
    this.height = 64,
  });

  final String label;
  final VoidCallback? onPressed;
  final DesignButtonStyle style;

  /// Figma の trailing（chevron_right）を出すか。
  final bool showTrailingIcon;

  /// ラベルの前に置く任意のウィジェット。
  final Widget? leading;

  final bool loading;
  final double height;

  Color? get _background {
    switch (style) {
      case DesignButtonStyle.primary:
        return AppColors.bgPrimary;
      case DesignButtonStyle.secondary:
        return AppColors.bgSecondary;
      case DesignButtonStyle.outline:
        return null;
      case DesignButtonStyle.danger:
        return AppColors.bgSurfaceDanger;
    }
  }

  Color get _foreground {
    switch (style) {
      case DesignButtonStyle.primary:
        return AppColors.textOnPrimary;
      case DesignButtonStyle.secondary:
        return AppColors.textPrimary;
      case DesignButtonStyle.outline:
        return AppColors.textBrand;
      case DesignButtonStyle.danger:
        return AppColors.textDanger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: _background ?? Colors.transparent,
        borderRadius: AppRadius.button,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: AppRadius.button,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: AppRadius.button,
              border: style == DesignButtonStyle.outline
                  ? Border.all(color: AppColors.borderGreenToken, width: 1.5)
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: loading
                  ? [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _foreground,
                          ),
                        ),
                      ),
                    ]
                  : [
                      if (leading != null) ...[leading!, const SizedBox(width: 8)],
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.buttonL.copyWith(
                            color: _foreground,
                          ),
                        ),
                      ),
                      if (showTrailingIcon) ...[
                        const SizedBox(width: 8),
                        DesignIcon(
                          Symbols.chevron_right_rounded,
                          size: 24,
                          color: _foreground,
                        ),
                      ],
                    ],
            ),
          ),
        ),
      ),
    );
  }
}
