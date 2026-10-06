import 'package:ayg/models/user_profile.dart';
import 'package:ayg/models/workout_template.dart';
import 'package:ayg/screens/exercise/exercise_form_screen.dart';
import 'package:ayg/screens/exercise/exercise_form_template_actions.dart';
import 'package:ayg/screens/workout_template/workout_template_screens.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/widgets/exercise/exercise_met_calculation_section.dart';
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

  testWidgets('adding an exercise offers template creation', (tester) async {
    useWideWindow(tester);
    final controller = AppController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ExerciseFormScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    final create = find.text('テンプレートを作成');
    await tester.scrollUntilVisible(
      create,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(create, findsOneWidget);
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(find.text('種目を追加'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('template item editor uses the exercise activity menu', (
    tester,
  ) async {
    useWideWindow(tester);
    final controller = AppController()
      ..profile = UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 170,
        weightKg: 70,
      );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: WorkoutTemplateFormScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('種目を追加'));
    await tester.pumpAndSettle();

    expect(
      find.text(ExerciseMetCalculationSection.activityMenuHint),
      findsOneWidget,
    );
    expect(find.text('種目名'), findsNothing);

    await tester.tap(find.byKey(ExerciseMetCalculationSection.activityMenuKey));
    await tester.pumpAndSettle();
    final soccer = find.widgetWithText(ListTile, 'サッカー');
    await tester.scrollUntilVisible(
      soccer,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(soccer, findsOneWidget);

    await tester.tap(soccer);
    await tester.pumpAndSettle();

    expect(find.text('きつさ'), findsOneWidget);
    expect(find.text('実施時間（分）'), findsOneWidget);
    expect(find.text('追加消費'), findsNothing);

    final duration = find.byKey(ExerciseMetCalculationSection.durationFieldKey);
    await tester.scrollUntilVisible(
      duration,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(duration, '30');
    await tester.pumpAndSettle();

    expect(find.text('追加消費'), findsOneWidget);
    expect(find.textContaining('kcal'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
