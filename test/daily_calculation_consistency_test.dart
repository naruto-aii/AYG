import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/alcohol_entry.dart';
import 'package:ayg/models/calculation/goal_pace.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/config/open_food_facts_config.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/screens/home/home_screen.dart';
import 'package:ayg/screens/settings/daily_calculation_explanation_screen.dart';
import 'package:ayg/state/app_controller.dart';

OpenFoodFactsService createOpenFoodFactsService() {
  return OpenFoodFactsService(userAgent: OpenFoodFactsConfig.userAgent);
}

void main() {
  testWidgets('home and explanation screen show identical remaining and PFC', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);

    controller.setProfile(
      UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 175,
        weightKg: 75,
      ),
    );
    controller.setGoal(
      Goal(
        type: GoalType.lose,
        targetWeightKg: 70,
        targetDate: DateTime(2026, 12, 31),
        goalPace: GoalPace.slow,
      ),
    );
    controller.setNutritionSettings(
      const NutritionSettings(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
      ),
    );
    controller.foodEntries.add(
      FoodEntry(
        id: 'food-1',
        name: '昼食',
        kcalPerUnit: 600,
        quantity: 1,
        loggedAt: DateTime.now(),
      ),
    );
    controller.exerciseEntries.add(
      ExerciseEntry(
        id: 'ex-1',
        name: 'ウォーク',
        durationMin: 30,
        burnedKcal: 200,
        loggedAt: DateTime.now(),
        netKcal: 150,
        grossKcal: 200,
      ),
    );
    controller.alcoholEntries.add(
      AlcoholEntry(
        id: 'alc-1',
        beverageName: 'ビール',
        amount: 350,
        unit: 'ml',
        alcoholPercentage: 5,
        totalCalories: 150,
        pureAlcoholGrams: 14,
        alcoholCalories: 98,
        consumedAt: DateTime.now(),
      ),
    );
    controller.refreshDailySummary();

    final summary = controller.summary!;
    final homeRemaining = summary.isCalorieOverage
        ? summary.calorieOverageKcal
        : summary.remainingKcal;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          controller: controller,
          openFoodFactsService: createOpenFoodFactsService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining(homeRemaining.toStringAsFixed(0)), findsWidgets);

    await tester.tap(find.text('この数値の計算根拠'));
    await tester.pumpAndSettle();

    expect(find.byType(DailyCalculationExplanationScreen), findsOneWidget);
    expect(find.text('カロリー根拠'), findsOneWidget);
    expect(summary.macroBreakdown, isNotNull);
    expect(
      find.textContaining(summary.targetKcal.toStringAsFixed(0)),
      findsWidgets,
    );
    expect(find.text('ゆっくり'), findsOneWidget);

    if (summary.isCalorieOverage) {
      expect(find.textContaining('超過'), findsWidgets);
    } else {
      expect(
        find.textContaining(summary.remainingKcal.toStringAsFixed(0)),
        findsWidgets,
      );
    }

    expect(summary.remainingKcal, summary.remainingBreakdown!.rawRemainingKcal);
    expect(summary.targetKcal, summary.energyBreakdown!.goalFoodTargetKcal);
  });

  test('summary breakdown objects stay consistent for PFC display', () {
    final controller = AppController();
    controller.setProfile(
      UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 175,
        weightKg: 75,
      ),
    );
    controller.setGoal(
      Goal(
        type: GoalType.lose,
        targetWeightKg: 70,
        targetDate: DateTime(2026, 12, 31),
        goalPace: GoalPace.slow,
      ),
    );
    controller.setNutritionSettings(
      const NutritionSettings(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
      ),
    );
    controller.refreshDailySummary();

    final summary = controller.summary!;
    expect(summary.macroBreakdown!.proteinG, summary.targetProteinG);
    expect(summary.macroBreakdown!.fatG, summary.targetFatG);
    expect(summary.macroBreakdown!.carbG, summary.targetCarbG);
  });
}
