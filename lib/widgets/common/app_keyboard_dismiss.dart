import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Dismisses the software keyboard from anywhere in the app.
void dismissAppKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
}

/// Wraps the navigator so every keyboard can be closed by:
/// - tapping anywhere that is not a text field
/// - tapping × / 完了 on the bar above the keyboard
class AppKeyboardHost extends StatelessWidget {
  const AppKeyboardHost({super.key, required this.child});

  final Widget child;

  static const double accessoryHeight = 44;

  static bool hitsEditableText(Offset position, int viewId) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, position, viewId);
    for (final entry in result.path) {
      if (entry.target is RenderEditable) {
        return true;
      }
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent event) {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || !focus.hasFocus) {
      return;
    }
    if (hitsEditableText(event.position, event.viewId)) {
      return;
    }
    dismissAppKeyboard();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;
    final accessoryHeight = keyboardHeight > 0
        ? AppKeyboardHost.accessoryHeight
        : 0.0;

    return MediaQuery(
      data: media.copyWith(
        viewInsets: media.viewInsets.copyWith(
          bottom: keyboardHeight + accessoryHeight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _onPointerDown,
            child: child,
          ),
          if (keyboardHeight > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: keyboardHeight,
              child: Material(
                elevation: 8,
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: SizedBox(
                    height: AppKeyboardHost.accessoryHeight,
                    child: Row(
                      children: [
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: '閉じる',
                          onPressed: dismissAppKeyboard,
                          icon: const Icon(Icons.close),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: dismissAppKeyboard,
                          child: const Text('完了'),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
