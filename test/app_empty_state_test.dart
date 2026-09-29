import 'package:ayg/widgets/common/app_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppEmptyState centers message within available width', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            centered: true,
            message: '記録された食事はありません。右下のボタンから追加できます。',
          ),
        ),
      ),
    );

    final textFinder = find.text('記録された食事はありません。右下のボタンから追加できます。');
    expect(textFinder, findsOneWidget);

    final textBox = tester.getRect(textFinder);
    expect(textBox.left, greaterThan(16));
    expect(textBox.right, lessThan(390 - 16));
    expect(textBox.center.dx, closeTo(195, 40));
  });

  testWidgets('AppEmptyState stays centered at desktop width', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppEmptyState(centered: true, message: '記録された運動はありません'),
        ),
      ),
    );

    final textFinder = find.text('記録された運動はありません');
    final textBox = tester.getRect(textFinder);
    expect(textBox.center.dx, closeTo(720, 80));
  });
}
