import 'package:ayg/data/met_activity_catalog.dart';
import 'package:ayg/models/exercise_calculation_source.dart';
import 'package:ayg/models/exercise_category.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/models/weight_entry.dart';
import 'package:ayg/screens/exercise/exercise_form_screen.dart';
import 'package:ayg/services/exercise_calorie_calculator.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/widgets/exercise/exercise_met_calculation_section.dart';
import 'package:ayg/utils/nutrition_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = ExerciseCalorieCalculator();

  UserProfile profile({double weightKg = 70}) {
    return UserProfile(
      birthDate: DateTime(1990, 1, 1),
      gender: Gender.male,
      heightCm: 170,
      weightKg: weightKg,
    );
  }

  WeightEntry weightEntry({
    required String id,
    required double kg,
    required DateTime at,
  }) {
    return WeightEntry(
      id: id,
      weightKg: kg,
      recordedAt: at,
      source: WeightSource.manual,
    );
  }

  ExerciseEntry savedEntry({
    required String id,
    required DateTime loggedAt,
    double grossKcal = 500,
    double netKcal = 400,
    double weightKgSnapshot = 65,
    String calculationVersion = 'legacy-v0',
    String activityId = 'walk_brisk',
    int durationMin = 30,
  }) {
    return ExerciseEntry(
      id: id,
      name: 'テストウォーク',
      durationMin: durationMin,
      burnedKcal: grossKcal,
      loggedAt: loggedAt,
      category: ExerciseCategory.aerobic,
      activityId: activityId,
      metValue: 3.5,
      grossKcal: grossKcal,
      netKcal: netKcal,
      weightKgSnapshot: weightKgSnapshot,
      calculationSource: ExerciseCalculationSource.metEstimate,
      calculationVersion: calculationVersion,
      sourceKey: 'walking_moderate_3_5',
    );
  }

  Future<ExerciseMetFormState?> pumpMetSection(
    WidgetTester tester, {
    required AppController controller,
    required TextEditingController durationController,
    required TextEditingController grossController,
    required DateTime loggedAt,
    required bool isEditing,
    ExerciseEntry? initialEntry,
  }) async {
    ExerciseMetFormState? latestState;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExerciseMetCalculationSection(
            controller: controller,
            loggedAt: loggedAt,
            durationController: durationController,
            grossKcalController: grossController,
            isEditing: isEditing,
            initialEntry: initialEntry,
            onEstimateChanged: (state) => latestState = state,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return latestState;
  }

  group('ExerciseMetCalculationSection', () {
    testWidgets('edit open alone does not change saved calculation values', (
      tester,
    ) async {
      final controller = AppController();
      addTearDown(controller.dispose);

      final loggedAt = DateTime(2026, 8, 1, 18);
      controller.profile = profile(weightKg: 70);
      controller.weightEntries.add(
        weightEntry(id: 'w1', kg: 71, at: DateTime(2026, 8, 1, 8)),
      );

      final entry = savedEntry(
        id: 'ex-1',
        loggedAt: loggedAt,
        grossKcal: 500,
        netKcal: 400,
        weightKgSnapshot: 65,
        calculationVersion: 'legacy-v0',
      );

      final durationController = TextEditingController(text: '30');
      final grossController = TextEditingController(text: '500');
      addTearDown(durationController.dispose);
      addTearDown(grossController.dispose);

      final state = await pumpMetSection(
        tester,
        controller: controller,
        durationController: durationController,
        grossController: grossController,
        loggedAt: loggedAt,
        isEditing: true,
        initialEntry: entry,
      );

      expect(grossController.text, '500');
      expect(state?.grossKcal, 500);
      expect(state?.netKcal, 400);
      expect(state?.weightKgSnapshot, 65);
    });

    testWidgets(
      'changing duration or activity does not update values until recalculate',
      (tester) async {
        final controller = AppController();
        addTearDown(controller.dispose);

        final loggedAt = DateTime(2026, 8, 1, 18);
        controller.profile = profile(weightKg: 70);
        controller.weightEntries.add(
          weightEntry(id: 'w1', kg: 71, at: DateTime(2026, 8, 1, 8)),
        );

        final entry = savedEntry(id: 'ex-1', loggedAt: loggedAt);
        final durationController = TextEditingController(text: '30');
        final grossController = TextEditingController(text: '500');
        addTearDown(durationController.dispose);
        addTearDown(grossController.dispose);

        await pumpMetSection(
          tester,
          controller: controller,
          durationController: durationController,
          grossController: grossController,
          loggedAt: loggedAt,
          isEditing: true,
          initialEntry: entry,
        );

        durationController.text = '60';
        await tester.pumpAndSettle();
        expect(grossController.text, '500');

        await tester.tap(
          find.byType(DropdownButtonFormField<MetActivityDefinition>),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('ランニング（中程度）').last);
        await tester.pumpAndSettle();
        expect(grossController.text, '500');
      },
    );

    testWidgets('recalculate button updates gross net weight and version', (
      tester,
    ) async {
      final controller = AppController();
      addTearDown(controller.dispose);

      final loggedAt = DateTime(2026, 8, 1, 18);
      controller.profile = profile(weightKg: 70);
      controller.weightEntries.add(
        weightEntry(id: 'w1', kg: 71, at: DateTime(2026, 8, 1, 8)),
      );

      final entry = savedEntry(
        id: 'ex-1',
        loggedAt: loggedAt,
        grossKcal: 500,
        netKcal: 400,
        weightKgSnapshot: 65,
        calculationVersion: 'legacy-v0',
      );

      final durationController = TextEditingController(text: '30');
      final grossController = TextEditingController(text: '500');
      addTearDown(durationController.dispose);
      addTearDown(grossController.dispose);

      await pumpMetSection(
        tester,
        controller: controller,
        durationController: durationController,
        grossController: grossController,
        loggedAt: loggedAt,
        isEditing: true,
        initialEntry: entry,
      );

      await tester.tap(find.text('保存済みの値を再計算する'));
      await tester.pumpAndSettle();

      final expected = calculator.estimate(
        met: 3.5,
        weightKg: 71,
        durationMinutes: 30,
      );

      expect(expected, isNotNull);
      expect(
        double.parse(grossController.text),
        closeTo(expected!.grossKcal, 0.1),
      );
      expect(
        find.textContaining(
          'net: ${formatNullableNutrient(expected.netKcal)} kcal',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('参照体重: 71.0 kg（体重記録）'), findsOneWidget);
    });

    testWidgets('manual override ON uses manual gross value', (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);

      final loggedAt = DateTime(2026, 8, 1, 12);
      controller.profile = profile(weightKg: 70);

      final durationController = TextEditingController(text: '30');
      final grossController = TextEditingController(text: '120');
      addTearDown(durationController.dispose);
      addTearDown(grossController.dispose);

      ExerciseMetFormState? latestState;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseMetCalculationSection(
              controller: controller,
              loggedAt: loggedAt,
              durationController: durationController,
              grossKcalController: grossController,
              isEditing: false,
              onEstimateChanged: (state) => latestState = state,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('消費 kcal を手動入力'));
      await tester.pumpAndSettle();

      grossController.text = '555';
      durationController.text = '31';
      await tester.pumpAndSettle();

      expect(latestState?.manualOverride, isTrue);
      expect(
        latestState?.calculationSource,
        ExerciseCalculationSource.manualOverride,
      );
      expect(latestState?.grossKcal, 555);
      expect(latestState?.netKcal, 555);
    });

    testWidgets('manual override OFF returns to automatic estimate', (
      tester,
    ) async {
      final controller = AppController();
      addTearDown(controller.dispose);

      final loggedAt = DateTime(2026, 8, 1, 12);
      controller.profile = profile(weightKg: 70);

      final durationController = TextEditingController(text: '30');
      final grossController = TextEditingController(text: '120');
      addTearDown(durationController.dispose);
      addTearDown(grossController.dispose);

      ExerciseMetFormState? latestState;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseMetCalculationSection(
              controller: controller,
              loggedAt: loggedAt,
              durationController: durationController,
              grossKcalController: grossController,
              isEditing: false,
              onEstimateChanged: (state) => latestState = state,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('消費 kcal を手動入力'));
      await tester.pumpAndSettle();
      grossController.text = '555';
      await tester.pumpAndSettle();

      await tester.tap(find.text('消費 kcal を手動入力'));
      await tester.pumpAndSettle();

      final expected = calculator.estimate(
        met: MetActivityCatalog.activities.first.defaultMet,
        weightKg: 70,
        durationMinutes: 30,
      );

      expect(latestState?.manualOverride, isFalse);
      expect(
        latestState?.calculationSource,
        ExerciseCalculationSource.metEstimate,
      );
      expect(latestState?.grossKcal, closeTo(expected!.grossKcal, 0.1));
      expect(latestState?.netKcal, closeTo(expected.netKcal, 0.1));
    });

    testWidgets('shows reason when no weight is available', (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);

      final durationController = TextEditingController(text: '30');
      final grossController = TextEditingController(text: '');
      addTearDown(durationController.dispose);
      addTearDown(grossController.dispose);

      await pumpMetSection(
        tester,
        controller: controller,
        durationController: durationController,
        grossController: grossController,
        loggedAt: DateTime(2026, 8, 1, 12),
        isEditing: false,
      );

      expect(
        find.textContaining('体重記録がありません。プロフィールに体重を設定するか、体重を記録してください。'),
        findsOneWidget,
      );
    });

    testWidgets('does not reference future weight entries', (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);

      final loggedAt = DateTime(2026, 8, 1, 12);
      controller.profile = profile(weightKg: 75);
      controller.weightEntries.addAll([
        weightEntry(id: 'past', kg: 68, at: DateTime(2026, 8, 1, 11)),
        weightEntry(id: 'future', kg: 60, at: DateTime(2026, 8, 1, 18)),
      ]);

      final durationController = TextEditingController(text: '30');
      final grossController = TextEditingController(text: '');
      addTearDown(durationController.dispose);
      addTearDown(grossController.dispose);

      await pumpMetSection(
        tester,
        controller: controller,
        durationController: durationController,
        grossController: grossController,
        loggedAt: loggedAt,
        isEditing: false,
      );

      expect(find.textContaining('参照体重: 68.0 kg（体重記録）'), findsOneWidget);
      expect(find.textContaining('60.0 kg'), findsNothing);
    });
  });

  group('ExerciseFormScreen MET edit persistence', () {
    testWidgets('input changes do not persist exercise entry until save', (
      tester,
    ) async {
      final controller = AppController();
      addTearDown(controller.dispose);

      final loggedAt = DateTime(2026, 8, 1, 18);
      controller.profile = profile(weightKg: 70);
      controller.weightEntries.add(
        weightEntry(id: 'w1', kg: 71, at: DateTime(2026, 8, 1, 8)),
      );

      final entry = savedEntry(
        id: 'ex-1',
        loggedAt: loggedAt,
        grossKcal: 500,
        netKcal: 400,
        weightKgSnapshot: 65,
      );
      controller.exerciseEntries.add(entry);

      await tester.pumpWidget(
        MaterialApp(
          home: ExerciseFormScreen(controller: controller, entry: entry),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, '実施時間（分）'),
        '60',
      );
      await tester.pumpAndSettle();

      expect(controller.exerciseEntries.single.durationMin, 30);
      expect(controller.exerciseEntries.single.grossKcal, 500);
      expect(controller.exerciseEntries.single.netKcal, 400);
      expect(controller.exerciseEntries.single.weightKgSnapshot, 65);
    });
  });
}
