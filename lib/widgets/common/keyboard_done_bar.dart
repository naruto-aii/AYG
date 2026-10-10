import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// キーボードの上に重ねる「完了」の高さ。
const keyboardDoneBarHeight = 44.0;

/// キーボードのすぐ上に出す「完了」。数字キーボードには閉じるキーが無い。
class KeyboardDoneBar extends StatelessWidget {
  const KeyboardDoneBar({super.key});

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset <= 0) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: 0,
      right: 0,
      bottom: inset,
      child: const KeyboardDoneBarSurface(),
    );
  }
}

/// 「完了」バー本体。位置は呼び出し側が決める。
class KeyboardDoneBarSurface extends StatelessWidget {
  const KeyboardDoneBarSurface({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgSurface,
      child: Container(
        height: keyboardDoneBarHeight,
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          border: Border(top: BorderSide(color: AppColors.borderDefault)),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: TextButton(
          onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Text(
            '完了',
            style: AppTypography.titleS.copyWith(color: AppColors.textBrand),
          ),
        ),
      ),
    );
  }
}
