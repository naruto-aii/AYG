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

  testWidgets(
    'goal settings shows calorie and PFC fields before switching mode',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authRepository = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
      );
      final controller = createController(authRepository: authRepository);

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

      expect(find.text('1日の食事目標'), findsOneWidget);
      expect(find.text('自動で計算'), findsOneWidget);
      expect(find.text('自分で入力'), findsOneWidget);
      expect(find.byKey(const Key('goal-target-kcal')), findsOneWidget);
      expect(find.byKey(const Key('goal-target-protein')), findsOneWidget);
      expect(find.byKey(const Key('goal-target-fat')), findsOneWidget);
      expect(find.byKey(const Key('goal-target-carb')), findsOneWidget);

      final kcalTop = tester
          .getTopLeft(find.byKey(const Key('goal-target-kcal')))
          .dy;
      expect(kcalTop, lessThan(700));

      await tester.enterText(find.byKey(const Key('goal-target-kcal')), '2000');
      await tester.enterText(
        find.byKey(const Key('goal-target-protein')),
        '130',
      );
      await tester.enterText(find.byKey(const Key('goal-target-fat')), '55');
      await tester.enterText(find.byKey(const Key('goal-target-carb')), '220');
      await tester.pump();
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));

      final saved = controller.nutritionSettings!;
      expect(saved.calorieTargetMode, CalorieTargetMode.manual);
      expect(saved.manualTargetKcal, 2000);
      expect(saved.manualProteinG, 130);
      expect(saved.manualFatG, 55);
      expect(saved.manualCarbG, 220);
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
      expect(controller.nutritionSettings!.usesManualTargets, isTrue);
      expect(controller.summary!.targetKcal, 2000);

      await openGoalSettings(tester);
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
}
