import 'package:ayg/models/workout_template.dart';
import 'package:ayg/screens/exercise/exercise_form_template_actions.dart';
import 'package:ayg/screens/workout_template/workout_template_screens.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void useWideWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('template form shows fields on a wide window', (tester) async {
    useWideWindow(tester);
    final controller = AppController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: WorkoutTemplateFormScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('テンプレート作成'), findsOneWidget);
    expect(find.text('テンプレート名'), findsOneWidget);
    expect(find.text('種目を追加'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
  });

  testWidgets('template apply shows register on a wide window', (tester) async {
    useWideWindow(tester);
    final controller = AppController();
    addTearDown(controller.dispose);
    final now = DateTime(2026, 9, 30);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutTemplateApplyScreen(
          controller: controller,
          template: WorkoutTemplate(
            templateId: 'tpl-1',
            ownerUserId: 'user-1',
            name: '朝の運動',
            normalizedName: '朝の運動',
            createdAt: now,
            updatedAt: now,
          ),
          items: [
            WorkoutTemplateItem(
              itemId: 'item-1',
              name: 'ウォーキング',
              durationMin: 30,
              sortOrder: 1,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('朝の運動'), findsOneWidget);
    expect(find.text('ウォーキング'), findsOneWidget);
    expect(find.text('一括登録'), findsOneWidget);
  });
}
