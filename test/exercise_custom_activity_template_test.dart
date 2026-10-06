import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/screens/exercise/exercise_form_screen.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/widgets/design/design_button.dart';
import 'package:ayg/widgets/exercise/exercise_met_calculation_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/in_memory_workout_template_repository.dart';

void main() {
  UserProfile profile() {
    return UserProfile(
      birthDate: DateTime(1990, 1, 1),
      gender: Gender.male,
      heightCm: 170,
      weightKg: 70,
    );
  }

  Future<void> openForm(WidgetTester tester, AppController controller) async {
    await tester.tap(find.text('運動を追加する'));
    await tester.pumpAndSettle();
    expect(find.text('運動を追加'), findsOneWidget);
  }

  Future<void> pumpHost(WidgetTester tester, AppController controller) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ExerciseFormScreen(controller: controller),
                    ),
                  );
                },
                child: const Text('運動を追加する'),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> enterUnmatchedName(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(ExerciseMetCalculationSection.activityMenuKey));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(ExerciseMetCalculationSection.searchFieldKey),
      name,
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'ランニング'), findsNothing);
    expect(find.widgetWithText(ListTile, 'サッカー'), findsNothing);
    expect(find.text('一致する種目はありません'), findsOneWidget);
  }

  String displayName(WidgetTester tester) {
    final nameField = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .firstWhere(
          (field) =>
              field.key != ExerciseMetCalculationSection.durationFieldKey,
        );
    return nameField.controller!.text;
  }

  group('custom activity template prompt', () {
    testWidgets('unmatched name opens the custom form from the field', (
      tester,
    ) async {
      final controller = AppController(
        workoutTemplateRepository: InMemoryWorkoutTemplateRepository(),
      );
      addTearDown(controller.dispose);
      controller.profile = profile();
      await pumpHost(tester, controller);
      await openForm(tester, controller);

      await enterUnmatchedName(tester, 'オリジナル競技');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'ランニング'), findsNothing);
      expect(find.text('この名前で登録'), findsNothing);
      expect(displayName(tester), 'オリジナル競技');
      expect(find.text('その他（手入力）'), findsWidgets);
    });

    testWidgets('yes adds a template that can be picked without typing', (
      tester,
    ) async {
      final controller = AppController(
        workoutTemplateRepository: InMemoryWorkoutTemplateRepository(),
      );
      addTearDown(controller.dispose);
      controller.profile = profile();
      await pumpHost(tester, controller);
      await openForm(tester, controller);

      await enterUnmatchedName(tester, 'オリジナル競技');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(displayName(tester), 'オリジナル競技');

      await tester.enterText(
        find.byKey(ExerciseMetCalculationSection.durationFieldKey),
        '30',
      );
      await tester.enterText(
        find.byKey(ExerciseMetCalculationSection.manualKcalFieldKey),
        '180',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DesignButton, '保存'));
      await tester.pumpAndSettle();

      expect(find.text('テンプレートに追加'), findsOneWidget);
      expect(find.textContaining('「オリジナル競技」をテンプレートに追加しますか？'), findsOneWidget);
      expect(
        tester
            .widget<DesignButton>(find.widgetWithText(DesignButton, 'はい'))
            .showTrailingIcon,
        isFalse,
      );
      expect(
        tester
            .widget<DesignButton>(find.widgetWithText(DesignButton, 'いいえ'))
            .showTrailingIcon,
        isFalse,
      );

      await tester.tap(find.widgetWithText(DesignButton, 'はい'));
      await tester.pumpAndSettle();

      expect(controller.exerciseEntries, hasLength(1));
      expect(controller.exerciseEntries.single.name, 'オリジナル競技');
      expect(controller.exerciseEntries.single.activityId, 'custom');
      expect(controller.exerciseEntries.single.durationMin, 30);
      final saved = await controller.listCustomActivityTemplates();
      expect(saved, hasLength(1));
      expect(saved.single.name, 'オリジナル競技');

      await openForm(tester, controller);
      await tester.tap(
        find.byKey(ExerciseMetCalculationSection.activityMenuKey),
      );
      await tester.pumpAndSettle();
      final tile = find.widgetWithText(ListTile, 'オリジナル競技');
      expect(tile, findsOneWidget);
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(displayName(tester), 'オリジナル競技');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(ExerciseMetCalculationSection.durationFieldKey),
            )
            .controller!
            .text,
        '30',
      );
      await tester.enterText(
        find.byKey(ExerciseMetCalculationSection.manualKcalFieldKey),
        '180',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DesignButton, '保存'));
      await tester.pumpAndSettle();

      expect(find.text('テンプレートに追加'), findsNothing);
      expect(controller.exerciseEntries, hasLength(2));
      expect(await controller.listCustomActivityTemplates(), hasLength(1));
    });

    testWidgets('no saves this entry and does not add a template', (
      tester,
    ) async {
      final controller = AppController(
        workoutTemplateRepository: InMemoryWorkoutTemplateRepository(),
      );
      addTearDown(controller.dispose);
      controller.profile = profile();
      await pumpHost(tester, controller);
      await openForm(tester, controller);

      await enterUnmatchedName(tester, 'オリジナル競技');
      await tester.ensureVisible(
        find.byKey(ExerciseMetCalculationSection.customFromQueryKey),
      );
      await tester.tap(
        find.byKey(ExerciseMetCalculationSection.customFromQueryKey),
      );
      await tester.pumpAndSettle();
      expect(displayName(tester), 'オリジナル競技');
      expect(find.widgetWithText(ListTile, 'ランニング'), findsNothing);

      await tester.enterText(
        find.byKey(ExerciseMetCalculationSection.durationFieldKey),
        '20',
      );
      await tester.enterText(
        find.byKey(ExerciseMetCalculationSection.manualKcalFieldKey),
        '90',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DesignButton, '保存'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DesignButton, 'いいえ'));
      await tester.pumpAndSettle();

      expect(controller.exerciseEntries, hasLength(1));
      expect(controller.exerciseEntries.single.name, 'オリジナル競技');
      expect(await controller.listCustomActivityTemplates(), isEmpty);

      await openForm(tester, controller);
      expect(find.widgetWithText(ListTile, 'ランニング'), findsNothing);
      await tester.tap(
        find.byKey(ExerciseMetCalculationSection.activityMenuKey),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'オリジナル競技'), findsNothing);
      expect(find.widgetWithText(ListTile, 'ランニング'), findsOneWidget);
    });

    testWidgets('dismissing the prompt does not save the entry', (
      tester,
    ) async {
      final controller = AppController(
        workoutTemplateRepository: InMemoryWorkoutTemplateRepository(),
      );
      addTearDown(controller.dispose);
      controller.profile = profile();
      await pumpHost(tester, controller);
      await openForm(tester, controller);

      await enterUnmatchedName(tester, 'オリジナル競技');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(ExerciseMetCalculationSection.durationFieldKey),
        '15',
      );
      await tester.enterText(
        find.byKey(ExerciseMetCalculationSection.manualKcalFieldKey),
        '40',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DesignButton, '保存'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(find.text('テンプレートに追加'), findsNothing);
      expect(controller.exerciseEntries, isEmpty);
      expect(await controller.listCustomActivityTemplates(), isEmpty);
      expect(find.text('運動を追加'), findsOneWidget);
    });
  });
}
