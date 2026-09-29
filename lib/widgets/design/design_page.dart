import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../layout/design_screen.dart';
import 'design_icon.dart';

/// Figma の画面構成（StatusBar / header / body / bottom / TabBar）を
/// そのまま組み立てる土台。
///
/// 中身はすべて Figma と同じ 390pt 座標系で書く。上下の端末固有領域
/// （ステータスバー・ホームインジケータ）は実機の値を使う。
class DesignPage extends StatelessWidget {
  const DesignPage({
    super.key,
    required this.body,
    this.header,
    this.bottomBar,
    this.tabBar,
    this.background,
    this.backgroundColor,
    this.bodyPadding = const EdgeInsets.symmetric(horizontal: 16),
    this.scrollable = true,
    this.scrollController,
  });

  /// スクロールする本文。
  final Widget body;

  /// ステータスバー直下に固定される行。
  final Widget? header;

  /// 本文の下に固定されるアクション領域。
  final Widget? bottomBar;

  /// 画面最下部のタブバー。
  final Widget? tabBar;

  final Widget? background;
  final Color? backgroundColor;
  final EdgeInsets bodyPadding;
  final bool scrollable;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    // Scaffold は Material の祖先とキーボード回避のために必要。
    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.bgPage,
      body: DesignScreen(
        background: background,
        backgroundColor: backgroundColor,
        child: Builder(
          builder: (context) {
            final padding = MediaQuery.paddingOf(context);
            final content = Padding(padding: bodyPadding, child: body);

            return Column(
              children: [
                SizedBox(height: padding.top),
                ?header,
                Expanded(
                  child: scrollable
                      ? SingleChildScrollView(
                          controller: scrollController,
                          child: content,
                        )
                      : content,
                ),
                if (bottomBar != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: bottomBar,
                  ),
                if (tabBar != null)
                  tabBar!
                else
                  SizedBox(height: padding.bottom),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Figma: header（戻る / スキップ などを置く 44pt の行）。
class DesignHeader extends StatelessWidget {
  const DesignHeader({
    super.key,
    this.leading,
    this.trailing,
    this.center,
    this.height = 44,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final Widget? leading;
  final Widget? trailing;
  final Widget? center;
  final double height;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: padding,
        child: Stack(
          children: [
            if (center != null) Center(child: center),
            if (leading != null)
              Align(alignment: Alignment.centerLeft, child: leading),
            if (trailing != null)
              Align(alignment: Alignment.centerRight, child: trailing),
          ],
        ),
      ),
    );
  }
}

/// Figma: 「‹ 戻る」（chevron_left 18 ＋ Label/M）。
class DesignBackButton extends StatelessWidget {
  const DesignBackButton({super.key, this.onPressed, this.label = '戻る'});

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed ?? () => Navigator.of(context).maybePop(),
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DesignIcon(
              Symbols.chevron_left_rounded,
              size: 18,
              color: AppColors.iconMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelM.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Figma の画面冒頭（戻る・見出し・リード文）。
///
/// 押し出し画面は「戻る」付き、タブ直下の画面は [showBack] を false にする。
class DesignTitleBlock extends StatelessWidget {
  const DesignTitleBlock({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = true,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;

  /// 見出しの右端に置くもの（カレンダーや追加ボタンなど）。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: showBack ? 14 : 20),
        if (showBack) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: DesignBackButton(onPressed: onBack),
          ),
          const SizedBox(height: 2),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: Text(title, style: AppTypography.headingL)),
            ?trailing,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
