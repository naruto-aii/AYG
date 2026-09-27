import 'package:ayg/widgets/common/app_keyboard_dismiss.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows close and done when the keyboard inset is open', (
    tester,
  ) async {
    addTearDown(tester.view.resetViewInsets);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            AppKeyboardHost(child: child ?? const SizedBox.shrink()),
        home: const Scaffold(body: TextField()),
      ),
    );
    await tester.pump();

    expect(find.text('完了'), findsOneWidget);
    expect(find.byTooltip('閉じる'), findsOneWidget);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

    await tester.tap(find.text('完了'));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.hasFocus, isFalse);
  });

  testWidgets('tapping outside a field dismisses focus', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            AppKeyboardHost(child: child ?? const SizedBox.shrink()),
        home: const Scaffold(
          body: Column(
            children: [
              TextField(),
              SizedBox(height: 80, width: double.infinity, child: Text('外')),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

    await tester.tap(find.text('外'));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.hasFocus, isFalse);
  });
}
