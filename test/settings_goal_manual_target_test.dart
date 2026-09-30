import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/calculation/calorie_target_mode.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/screens/settings/settings_screen.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';

import 'mocks/mock_authentication_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final referenceDate = DateTime(2026, 9, 30);

  AppController createController({
    required MockAuthenticationRepository authRepository,
  }) {
    final controller = AppController(authenticationRepository: authRepository);
    controller.setProfile(
      UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 175,
        weightKg: 75,
      ),
    );
    controller.setNutritionSettings(
      const NutritionSettings(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
      ),
    );
    controller.setGoal(
      Goal(
        type: GoalType.maintain,
        targetWeightKg: 75,
        targetDate: referenceDate.add(const Duration(days: 90)),
      ),
    );
    return controller;
  }

  Future<void> openGoalSettings(WidgetTester tester) async {
    await tester.tap(find.text(AppStrings.settingsGoal));
    await tester.pumpAndSettle();
  }

  Future<void> pumpSettings(
    WidgetTester tester, {
    required AppController controller,
    required MockAuthenticationRepository authRepository,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          controller: controller,
          authenticationRepository: authRepository,
          hideHealthSettings: true,
        ),
      ),
    );
    await openGoalSettings(tester);
  }

  Future<void> replaceGoalField(
    WidgetTester tester,
    String key,
    String value,
  ) async {
    await tester.enterText(find.byKey(Key(key)), value);
    await tester.pump();
  }

  String goalFieldText(WidgetTester tester, String key) {
    return tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
  }

  testWidgets(
    'goal settings shows calorie and PFC fields before switching mode',
    (WidgetTester tester) async {
      final authRepository = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
      );
      final controller = createController(authRepository: authRepository);
      await pumpSettings(
        tester,
        controller: controller,
        authRepository: authRepository,
      );

      expect(find.text('目標カロリーの手入力'), findsOneWidget);
      expect(find.text('自分で入力'), findsOneWidget);
      expect(find.text('自動で計算'), findsNothing);
      expect(find.text('ゆっくり'), findsNothing);
      expect(find.text('減量ペース'), findsNothing);
      expect(find.byKey(const Key('goal-target-kcal')), findsOneWidget);
      expect(find.byKey(const Key('goal-target-protein')), findsOneWidget);
      expect(find.byKey(const Key('goal-target-fat')), findsOneWidget);
      expect(find.byKey(const Key('goal-target-carb')), findsOneWidget);

      final weightBottom = tester
          .getBottomLeft(find.text(AppStrings.targetWeightKg))
          .dy;
      final dateBottom = tester
          .getBottomLeft(find.text(AppStrings.targetDate))
          .dy;
      final kcalTop = tester
          .getTopLeft(find.byKey(const Key('goal-target-kcal')))
          .dy;
      expect(kcalTop, greaterThan(weightBottom));
      expect(kcalTop, greaterThan(dateBottom));

      await replaceGoalField(tester, 'goal-target-kcal', '2000');
      await replaceGoalField(tester, 'goal-target-protein', '130');
      await replaceGoalField(tester, 'goal-target-fat', '0');
      await replaceGoalField(tester, 'goal-target-fat', '55');
      expect(goalFieldText(tester, 'goal-target-carb'), '246.3');
      final carbState = tester.state<EditableTextState>(
        find.descendant(
          of: find.byKey(const Key('goal-target-carb')),
          matching: find.byType(EditableText),
        ),
      );
      expect(carbState.renderEditable.text!.toPlainText(), '246.3');

      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));

      final saved = controller.nutritionSettings!;
      expect(saved.calorieTargetMode, CalorieTargetMode.manual);
      expect(saved.manualTargetKcal, 2000);
      expect(saved.manualProteinG, 130);
      expect(saved.manualFatG, 55);
      expect(saved.manualCarbG, 246.3);
      expect(saved.usesManualTargets, isTrue);

      controller.setProfile(
        UserProfile(
          birthDate: DateTime(1990, 1, 1),
          gender: Gender.male,
          heightCm: 175,
          weightKg: 80,
        ),
      );
      controller.setGoal(
        Goal(
          type: GoalType.lose,
          targetWeightKg: 70,
          targetDate: referenceDate.add(const Duration(days: 30)),
        ),
      );

      expect(controller.nutritionSettings!.manualTargetKcal, 2000);
      expect(controller.nutritionSettings!.manualProteinG, 130);
      expect(controller.nutritionSettings!.manualCarbG, 246.3);
      expect(controller.nutritionSettings!.usesManualTargets, isTrue);
      expect(controller.summary!.targetKcal, 2000);

      await openGoalSettings(tester);
      await tester.ensureVisible(find.text('自動で計算'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('自動で計算'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));

      expect(
        controller.nutritionSettings!.calorieTargetMode,
        CalorieTargetMode.automatic,
      );
      expect(controller.nutritionSettings!.usesManualTargets, isFalse);
      expect(controller.summary!.targetKcal, isNot(2000));

      await authRepository.dispose();
    },
  );

  testWidgets('goal settings rejects a negative remainder', (tester) async {
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    );
    final controller = createController(authRepository: authRepository);
    await pumpSettings(
      tester,
      controller: controller,
      authRepository: authRepository,
    );

    await replaceGoalField(tester, 'goal-target-kcal', '500');
    await replaceGoalField(tester, 'goal-target-protein', '30');
    await replaceGoalField(tester, 'goal-target-fat', '0');
    await replaceGoalField(tester, 'goal-target-fat', '500');

    expect(find.textContaining('炭水化物がマイナス'), findsOneWidget);
    expect(goalFieldText(tester, 'goal-target-carb'), isEmpty);

    await tester.tap(find.text(AppStrings.save));
    await tester.pump();

    expect(
      controller.nutritionSettings!.calorieTargetMode,
      CalorieTargetMode.automatic,
    );
    expect(controller.nutritionSettings!.usesManualTargets, isFalse);
    expect(find.text('目標カロリーの手入力'), findsOneWidget);

    await authRepository.dispose();
  });

  testWidgets('goal settings rejects kcal that does not match PFC', (
    tester,
  ) async {
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    );
    final controller = createController(authRepository: authRepository);
    await pumpSettings(
      tester,
      controller: controller,
      authRepository: authRepository,
    );

    await replaceGoalField(tester, 'goal-target-kcal', '2000');
    await replaceGoalField(tester, 'goal-target-protein', '130');
    await replaceGoalField(tester, 'goal-target-fat', '0');
    await replaceGoalField(tester, 'goal-target-fat', '55');
    expect(goalFieldText(tester, 'goal-target-carb'), '246.3');

    await replaceGoalField(tester, 'goal-target-carb', '20000');
    expect(find.textContaining('カロリーとPFCが合いません'), findsOneWidget);

    await tester.tap(find.text(AppStrings.save));
    await tester.pump();

    expect(controller.nutritionSettings!.usesManualTargets, isFalse);
    expect(find.text('目標カロリーの手入力'), findsOneWidget);

    await authRepository.dispose();
  });
}
