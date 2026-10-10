import 'package:flutter/material.dart';

import '../../config/demo_mode.dart';
import '../../theme/app_colors.dart';
import '../common/keyboard_done_bar.dart';
import 'tablet_surface.dart';

/// アプリの [MaterialApp.builder]。
///
/// キーボードの「完了」を載せる。iPad ではダイアログとシートの幅を抑え、
/// 「完了」バーのぶん本文をキーボードの上へ上げる。デモの広い窓だけ、
/// 従来どおり 390 幅に収める。iPhone（キーボードを出していないとき）の
/// 木は、以前の Stack と同じ。
Widget buildCalonaviFrame(BuildContext context, Widget? child) {
  final media = MediaQuery.of(context);
  final keyboard = media.viewInsets.bottom;
  final tablet = isTabletLayout(media.size);
  final Widget stack;
  if (tablet && keyboard > 0) {
    stack = MediaQuery(
      data: media.copyWith(
        viewInsets: media.viewInsets.copyWith(
          bottom: keyboard + keyboardDoneBarHeight,
        ),
      ),
      child: Stack(
        children: [
          ?child,
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboard,
            child: const KeyboardDoneBarSurface(),
          ),
        ],
      ),
    );
  } else {
    stack = Stack(
      children: [?child, const KeyboardDoneBar()],
    );
  }
  final Widget framed = tablet
      ? Theme(
          data: tabletSurfaceTheme(
            Theme.of(context),
            media.size,
            media.viewInsets,
          ),
          child: stack,
        )
      : stack;
  if (!calonaviDemoMode) {
    return framed;
  }
  final size = media.size;
  if (size.width < 900) {
    return framed;
  }
  return ColoredBox(
    color: AppColors.bgPage,
    child: Center(
      child: SizedBox(
        width: 390,
        height: size.height,
        child: MediaQuery(
          data: media.copyWith(size: Size(390, size.height)),
          child: framed,
        ),
      ),
    ),
  );
}
