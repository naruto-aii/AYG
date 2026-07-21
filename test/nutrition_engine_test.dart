import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/health_snapshot.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/services/nutrition_engine.dart';

void main() {
  final engine = NutritionEngine();
  final referenceDate = DateTime(2026, 7, 21);
  final birthDateMale = DateTime(1990, 1, 1);
  final birthDateFemale = DateTime(1992, 6, 15);

  final maleProfile = UserProfile(
    birthDate: birthDateMale,
    gender: Gender.male,
    heightCm: 175,
    weightKg: 75,
  );

  final femaleProfile = UserProfile(
    birthDate: birthDateFemale,
    gender: Gender.female,
    heightCm: 160,
    weightKg: 55,
  );

  group('calculateBMR', () {
    test('male uses Mifflin-St Jeor male formula', () {
      final bmr = engine.calculateBMR(
        profile: maleProfile,
        referenceDate: referenceDate,
      );

      expect(bmr, closeTo(1668.75, 0.01));
    });

    test('female uses Mifflin-St Jeor female formula', () {
      final bmr = engine.calculateBMR(
        profile: femaleProfile,
        referenceDate: referenceDate,
      );

      expect(bmr, closeTo(1219.0, 0.01));
    });
  });

  group('TDEE', () {
    test('activity level applies factor to BMR', () {
      final bmr = engine.calculateBMR(
        profile: maleProfile,
        referenceDate: referenceDate,
      );
      final tdee = engine.calculateTDEEFromActivityFactor(
        bmr: bmr,
        activityLevel: ActivityLevel.moderate,
      );

      expect(tdee, closeTo(bmr * 1.55, 0.01));
    });

    test('health uses BMR plus active energy burned', () {
      final bmr = engine.calculateBMR(
        profile: maleProfile,
        referenceDate: referenceDate,
      );
      final tdee = engine.calculateTDEEFromHealth(
        bmr: bmr,
        activeEnergyBurnedKcal: 450,
      );

      expect(tdee, closeTo(bmr + 450, 0.01));
    });
  });

  group('calculateTargetCalories', () {
    final tdee = 2500.0;

    test('lose subtracts daily adjustment', () {
      final target = engine.calculateTargetCalories(
        goalType: GoalType.lose,
        tdee: tdee,
        dailyAdjustment: 300,
        targetDate: referenceDate.add(const Duration(days: 90)),
        referenceDate: referenceDate,
      );

      expect(target, 2200);
    });

    test('gain adds daily adjustment', () {
      final target = engine.calculateTargetCalories(
        goalType: GoalType.gain,
        tdee: tdee,
        dailyAdjustment: 300,
        targetDate: referenceDate.add(const Duration(days: 90)),
        referenceDate: referenceDate,
      );

      expect(target, 2800);
    });

    test('maintain equals TDEE', () {
      final target = engine.calculateTargetCalories(
        goalType: GoalType.maintain,
        tdee: tdee,
        dailyAdjustment: 300,
        targetDate: referenceDate.add(const Duration(days: 90)),
        referenceDate: referenceDate,
      );

      expect(target, tdee);
    });

    test('past target date returns TDEE', () {
      final target = engine.calculateTargetCalories(
        goalType: GoalType.lose,
        tdee: tdee,
        dailyAdjustment: 300,
        targetDate: referenceDate.subtract(const Duration(days: 1)),
        referenceDate: referenceDate,
      );

      expect(target, tdee);
    });
  });

  group('calculateDailyAdjustment', () {
    test('uses 7200 kcal per kg over remaining days', () {
      final adjustment = engine.calculateDailyAdjustment(
        goal: Goal(
          type: GoalType.lose,
          targetWeightKg: 70,
          targetDate: referenceDate.add(const Duration(days: 90)),
        ),
        currentWeightKg: 75,
        referenceDate: referenceDate,
      );

      expect(adjustment, closeTo(400, 0.01));
    });
  });

  group('calculateTargetMacros', () {
    test('lose uses 2.0g/kg protein and 0.8g/kg fat', () {
      final macros = engine.calculateTargetMacros(
        goalType: GoalType.lose,
        targetCalories: 2000,
        weightKg: 75,
      );

      expect(macros.proteinG, 150);
      expect(macros.fatG, 60);
      expect(macros.carbG, closeTo(215.0, 0.01));
    });
  });

  group('calculateRemainingCalories', () {
    test('remaining equals target minus food plus exercise', () {
      final remaining = engine.calculateRemainingCalories(
        targetCalories: 2000,
        foodCalories: 800,
        exerciseCalories: 200,
      );

      expect(remaining, 1400);
    });
  });

  group('calculateDailySummary', () {
    test('health integration ignores activity level', () {
      final summary = engine.calculateDailySummary(
        profile: maleProfile,
        goal: Goal(
          type: GoalType.maintain,
          targetWeightKg: 75,
          targetDate: referenceDate.add(const Duration(days: 90)),
        ),
        settings: const NutritionSettings(useHealthIntegration: true),
        healthSnapshot: const HealthSnapshot(activeEnergyBurnedKcal: 500),
        foodEntries: const [],
        exerciseEntries: const [],
        referenceDate: referenceDate,
      );

      final bmr = engine.calculateBMR(
        profile: maleProfile,
        referenceDate: referenceDate,
      );
      expect(summary.targetKcal, closeTo(bmr + 500, 0.01));
    });

    test('activity level integration uses activity factor', () {
      final summary = engine.calculateDailySummary(
        profile: maleProfile,
        goal: Goal(
          type: GoalType.maintain,
          targetWeightKg: 75,
          targetDate: referenceDate.add(const Duration(days: 90)),
        ),
        settings: const NutritionSettings(
          useHealthIntegration: false,
          activityLevel: ActivityLevel.moderate,
        ),
        foodEntries: [
          FoodEntry(
            id: 'food-1',
            name: 'テスト',
            kcalPerUnit: 500,
            quantity: 1,
            loggedAt: referenceDate,
          ),
        ],
        exerciseEntries: [
          ExerciseEntry(
            id: 'exercise-1',
            name: '走る',
            durationMin: 30,
            burnedKcal: 200,
            loggedAt: referenceDate,
          ),
        ],
        referenceDate: referenceDate,
      );

      final bmr = engine.calculateBMR(
        profile: maleProfile,
        referenceDate: referenceDate,
      );
      final expectedTarget = bmr * ActivityLevel.moderate.factor;
      expect(summary.targetKcal, closeTo(expectedTarget, 0.01));
      expect(summary.remainingKcal, closeTo(expectedTarget - 500 + 200, 0.01));
    });
  });
}
