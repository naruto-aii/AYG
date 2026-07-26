import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_health_repository.dart';

void main() {
  late AppController controller;
  late DateTime today;
  late DateTime yesterday;

  setUp(() {
    final now = DateTime.now();
    today = DateTime(now.year, now.month, now.day, 8);
    yesterday = today.subtract(const Duration(days: 1));

    controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
    );
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
        targetDate: today.add(const Duration(days: 90)),
      ),
    );
  });

  FoodEntry food({
    required String id,
    required double kcal,
    required DateTime loggedAt,
    double protein = 0,
    double fat = 0,
    double carb = 0,
  }) {
    return FoodEntry(
      id: id,
      name: id,
      kcalPerUnit: kcal,
      proteinPerUnit: protein,
      fatPerUnit: fat,
      carbPerUnit: carb,
      quantity: 1,
      loggedAt: loggedAt,
    );
  }

  ExerciseEntry exercise({
    required String id,
    required double burnedKcal,
    required DateTime loggedAt,
  }) {
    return ExerciseEntry(
      id: id,
      name: id,
      durationMin: 30,
      burnedKcal: burnedKcal,
      loggedAt: loggedAt,
    );
  }

  group('refreshDailySummary after deletion', () {
    test('food delete recalculates today intake and remaining kcal', () async {
      await controller.addFood(
        food(id: 'a', kcal: 300, loggedAt: today, protein: 10),
      );
      await controller.addFood(
        food(id: 'b', kcal: 200, loggedAt: today, protein: 5),
      );
      await controller.addFood(
        food(id: 'old', kcal: 1000, loggedAt: yesterday),
      );

      final before = controller.summary!;
      expect(before.intakeKcal, 500);
      expect(before.intakeProteinG, 15);

      await controller.deleteFood('a');

      final after = controller.summary!;
      expect(after.intakeKcal, 200);
      expect(after.intakeProteinG, 5);
      expect(after.remainingKcal, before.remainingKcal + 300);
    });

    test('exercise delete reduces remaining kcal', () async {
      await controller.addFood(food(id: 'food', kcal: 500, loggedAt: today));
      await controller.addExercise(
        exercise(id: 'run', burnedKcal: 300, loggedAt: today),
      );
      await controller.addExercise(
        exercise(id: 'old', burnedKcal: 400, loggedAt: yesterday),
      );

      final before = controller.summary!;
      expect(before.exerciseBurnKcal, 300);

      await controller.deleteExercise('run');

      final after = controller.summary!;
      expect(after.exerciseBurnKcal, 0);
      expect(after.remainingKcal, before.remainingKcal - 300);
    });

    test('last food delete zeroes intake', () async {
      await controller.addFood(food(id: 'only', kcal: 500, loggedAt: today));
      expect(controller.summary!.intakeKcal, 500);

      await controller.deleteFood('only');

      expect(controller.summary!.intakeKcal, 0);
      expect(controller.foodEntries, isEmpty);
    });
  });
}
