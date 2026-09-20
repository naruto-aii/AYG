import 'package:ayg/data/met_activity_catalog.dart';
import 'package:ayg/data/met_intensity_presets.dart';
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
      intensity: 'moderate',
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
    TextEditingController? nameController,
  }) async {
    ExerciseMetFormState? latestState;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ExerciseMetCalculationSection(
              controller: controller,
              loggedAt: loggedAt,
              durationController: durationController,
              grossKcalController: grossController,
              nameController: nameController,
              isEditing: isEditing,
              initialEntry: initialEntry,
              onEstimateChanged: (state) => latestState = state,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return latestState;
  }

  Future<void> pumpMetSectionWithState(
    WidgetTester tester, {
    required AppController controller,
    required TextEditingController durationController,
    required TextEditingController grossController,
    required DateTime loggedAt,
    required bool isEditing,
    ExerciseEntry? initialEntry,
    required void Function(ExerciseMetFormState state) onEstimateChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ExerciseMetCalculationSection(
              controller: controller,
              loggedAt: loggedAt,
              durationController: durationController,
              grossKcalController: grossController,
              isEditing: isEditing,
              initialEntry: initialEntry,
              onEstimateChanged: onEstimateChanged,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapCategoryChip(WidgetTester tester, String label) async {
    final chip = find.widgetWithText(FilterChip, label);
    await tester.scrollUntilVisible(
      chip,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  Future<void> tapActivityChip(WidgetTester tester, String label) async {
    final chip = find.widgetWithText(ChoiceChip, label);
    await tester.scrollUntilVisible(
      chip,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  Future<void> expandAdvanced(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('詳細設定'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('詳細設定'));
    await tester.pumpAndSettle();
  }

  Future<void> tapRecalculate(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('再計算'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('再計算'));
    await tester.pumpAndSettle();
  }

  Future<void> tapManualOverride(
    WidgetTester tester, {
    bool enable = true,
  }) async {
    if (find.byType(SwitchListTile).evaluate().isEmpty) {
      await expandAdvanced(tester);
    } else {
      await tester.scrollUntilVisible(
        find.byType(SwitchListTile),
        120,
        scrollable: find.byType(Scrollable).first,
      );
    }
    final switchFinder = find.byType(SwitchListTile);
    final switchTile = tester.widget<SwitchListTile>(switchFinder);
    if (switchTile.value != enable) {
      await tester.ensureVisible(switchFinder);
      await tester.pumpAndSettle();
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
    }
  }

  group('ExerciseMetCalculationSection', () {
    testWidgets('strength training offers light moderate hard intensities', (
      tester,
    ) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      controller.profile = profile();

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

      await tapCategoryChip(tester, '筋力トレーニング');

      expect(find.text('軽め'), findsOneWidget);
      expect(find.text('ふつう'), findsOneWidget);
      expect(find.text('きつい'), findsOneWidget);
      expect(find.textContaining('MET'), findsNothing);
    });

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

        await tapActivityChip(tester, 'ランニング・ジョギング');
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

      ExerciseMetFormState? latestState;
      await pumpMetSectionWithState(
        tester,
        controller: controller,
        durationController: durationController,
        grossController: grossController,
        loggedAt: loggedAt,
        isEditing: true,
        initialEntry: entry,
        onEstimateChanged: (state) => latestState = state,
      );

      await tapRecalculate(tester);

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
      expect(latestState?.netKcal, closeTo(expected.netKcal, 0.1));
      await expandAdvanced(tester);
      expect(find.textContaining('71.0 kg'), findsOneWidget);
    });

    testWidgets('manual override uses net kcal field', (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);

      final loggedAt = DateTime(2026, 8, 1, 12);
      controller.profile = profile(weightKg: 70);

      final durationController = TextEditingController(text: '30');
      final grossController = TextEditingController(text: '120');
      addTearDown(durationController.dispose);
      addTearDown(grossController.dispose);

      ExerciseMetFormState? latestState;
      await pumpMetSectionWithState(
        tester,
        controller: controller,
        durationController: durationController,
        grossController: grossController,
        loggedAt: loggedAt,
        isEditing: false,
        onEstimateChanged: (state) => latestState = state,
      );

      await tapManualOverride(tester);
      final netField = find.widgetWithText(TextField, '手動 追加消費 kcal（net）');
      await tester.ensureVisible(netField);
      await tester.pumpAndSettle();
      await tester.enterText(netField, '555');
      await tester.pumpAndSettle();

      expect(latestState?.manualOverride, isTrue);
      expect(
        latestState?.calculationSource,
        ExerciseCalculationSource.manualOverride,
      );
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
      await pumpMetSectionWithState(
        tester,
        controller: controller,
        durationController: durationController,
        grossController: grossController,
        loggedAt: loggedAt,
        isEditing: false,
        onEstimateChanged: (state) => latestState = state,
      );

      await tapManualOverride(tester);
      await tapManualOverride(tester, enable: false);

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
        find.textContaining('体重データがないため、消費カロリーを自動計算できません'),
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

      ExerciseMetFormState? latestState;
      await pumpMetSectionWithState(
        tester,
        controller: controller,
        durationController: durationController,
        grossController: grossController,
        loggedAt: loggedAt,
        isEditing: false,
        onEstimateChanged: (state) => latestState = state,
      );

      expect(latestState?.weightKgSnapshot, 68);
      expect(latestState?.weightKgSnapshot, isNot(60));
    });

    testWidgets('other category offers light moderate hard intensities', (
      tester,
    ) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      controller.profile = profile();

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

      await tapCategoryChip(tester, 'その他');

      expect(find.text('軽め'), findsOneWidget);
      expect(find.text('ふつう'), findsOneWidget);
      expect(find.text('きつい'), findsOneWidget);
      expect(
        MetActivityCatalog.findById('custom')?.intensityOptions,
        MetIntensityPresets.otherOptions,
      );
    });

    testWidgets('daily activity warns that PAL already includes housework', (
      tester,
    ) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      controller.profile = profile();

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

      await tapCategoryChip(tester, '日常活動・軽い運動');

      expect(find.textContaining('生活活動係数（PAL）にすでに含まれています'), findsOneWidget);
    });

    testWidgets('main surface shows net only without gross or MET', (
      tester,
    ) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      controller.profile = profile();

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

      expect(find.text('追加消費'), findsWidgets);
      expect(find.textContaining('残りカロリーに加算'), findsOneWidget);
      expect(find.textContaining('推定総消費'), findsNothing);
      expect(find.textContaining('MET'), findsNothing);
      expect(find.text('消費 kcal（gross）'), findsNothing);
    });

    testWidgets('selecting an activity fills the display name', (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      controller.profile = profile();

      final durationController = TextEditingController(text: '30');
      final grossController = TextEditingController(text: '');
      final nameController = TextEditingController();
      addTearDown(durationController.dispose);
      addTearDown(grossController.dispose);
      addTearDown(nameController.dispose);

      await pumpMetSection(
        tester,
        controller: controller,
        durationController: durationController,
        grossController: grossController,
        nameController: nameController,
        loggedAt: DateTime(2026, 8, 1, 12),
        isEditing: false,
      );

      await tapActivityChip(tester, 'ランニング・ジョギング');
      expect(nameController.text, 'ランニング・ジョギング');
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

    testWidgets('add form hides template shortcuts and required gross kcal', (
      tester,
    ) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      controller.profile = profile();

      await tester.pumpWidget(
        MaterialApp(home: ExerciseFormScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('テンプレートから追加'), findsNothing);
      expect(find.text('テンプレートを新規作成'), findsNothing);
      expect(find.text('入力内容をテンプレートとして保存'), findsOneWidget);
      expect(find.text('消費 kcal（gross）'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('メモ'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('メモ'), findsOneWidget);
    });

    testWidgets('strength category shows sets reps and lift weight', (
      tester,
    ) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      controller.profile = profile();

      await tester.pumpWidget(
        MaterialApp(home: ExerciseFormScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      await tapCategoryChip(tester, '筋力トレーニング');

      await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, 'セット'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.widgetWithText(TextFormField, 'セット'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '回数'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '重量（kg）'), findsOneWidget);
    });
  });
}
