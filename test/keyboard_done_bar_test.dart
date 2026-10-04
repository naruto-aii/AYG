import 'package:ayg/widgets/common/keyboard_done_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('完了 takes focus off the text field', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final focus = FocusNode();
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return Stack(
            children: [
              if (child != null) child,
              const KeyboardDoneBar(),
            ],
          );
        },
        home: Scaffold(body: TextField(focusNode: focus, autofocus: true)),
      ),
    );
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(find.text('完了'), findsNothing);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    expect(find.text('完了'), findsOneWidget);

    await tester.tap(find.text('完了'));
    await tester.pump();
    expect(focus.hasFocus, isFalse);
  });
}
