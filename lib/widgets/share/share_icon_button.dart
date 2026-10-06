import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../design/design_icon.dart';

/// 画面を圧迫しない共有アイコン。
class ShareIconButton extends StatelessWidget {
  const ShareIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      icon: const DesignIcon(
        Symbols.ios_share_rounded,
        size: 20,
        color: AppColors.iconMuted,
      ),
    );
  }
}
