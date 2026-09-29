import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import 'icon_circle.dart';

/// Figma: TextField コンポーネントの外枠（アイコン付き見出し＋入力欄）。
class DesignFieldCard extends StatelessWidget {
  const DesignFieldCard({
    super.key,
    required this.icon,
    required this.label,
    required this.child,
    this.tone = IconCircleTone.green,
    this.verticalPadding = 14,
  });

  /// 24pt 相当のアイコン。色は呼び出し側で [IconCircle.foregroundOf] を使う。
  final Widget icon;
  final String label;
  final Widget child;
  final IconCircleTone tone;

  /// Figma: TextField は 14、性別カードのように入力欄を持たない枠は 18。
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: verticalPadding),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceAlt,
        borderRadius: AppRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconCircle(tone: tone, size: 36, child: icon),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: AppTypography.titleM)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Figma: TextField の入力欄（白地・枠線つき）。
class DesignInputBox extends StatelessWidget {
  const DesignInputBox({
    super.key,
    required this.child,
    this.suffix,
    this.onTap,
    this.trailing,
    this.radius = AppRadius.md,
    this.verticalPadding = 13,
  });

  final Widget child;

  /// 「cm」「kg」などの単位表記。
  final String? suffix;

  /// タップで日付ピッカーなどを開く場合に指定する。
  final VoidCallback? onTap;

  /// 単位ではなくアイコンを置く場合。
  final Widget? trailing;

  final double radius;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: verticalPadding),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        children: [
          Expanded(child: child),
          if (suffix != null) ...[
            const SizedBox(width: 8),
            Text(
              suffix!,
              style: AppTypography.labelM.copyWith(color: AppColors.textMuted),
            ),
          ],
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );

    if (onTap == null) {
      return box;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: box,
    );
  }
}

/// [DesignInputBox] の中に置く素の入力欄。
class DesignTextInput extends StatelessWidget {
  const DesignTextInput({
    super.key,
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final TextAlign textAlign;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      maxLines: maxLines,
      textAlign: textAlign,
      enabled: enabled,
      cursorColor: AppColors.textBrand,
      style: AppTypography.bodyL.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: hintText,
        hintStyle: AppTypography.bodyL.copyWith(color: AppColors.textMuted),
      ),
    );
  }
}

/// Figma: ラベルを左、入力欄を右に置く横並びの行（07 アルコールを追加など）。
class DesignRowField extends StatelessWidget {
  const DesignRowField({
    super.key,
    required this.label,
    required this.child,
    this.labelWidth = 120,
  });

  final String label;
  final Widget child;

  /// Figma の実測値（120 または 138）。
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: AppTypography.titleS),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Figma: 検索欄（白地・枠線・右端に虫めがね）。
class DesignSearchField extends StatelessWidget {
  const DesignSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onSubmitted,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              cursorColor: AppColors.textBrand,
              style: AppTypography.bodyL.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: hintText,
                hintStyle: AppTypography.bodyL.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const AppIcon(AppIcons.search, size: 18, color: AppColors.iconMuted),
        ],
      ),
    );
  }
}
