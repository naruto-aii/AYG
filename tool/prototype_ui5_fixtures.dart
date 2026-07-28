import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_entry_source.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/state/app_controller.dart';

import '../test/mocks/mock_authentication_repository.dart';
import '../test/mocks/mock_health_repository.dart';

const prototypeUi5UserId = 'prototype-user';

Future<AppController> createPrototypeUi5Controller() async {
  final controller = AppController(
    healthRepository: MockHealthRepository(isAvailable: false),
    authenticationRepository: MockAuthenticationRepository(
      currentUser: const AuthUser(
        id: prototypeUi5UserId,
        email: 'prototype@example.com',
      ),
    ),
  );

  controller.setProfile(
    UserProfile(
      birthDate: DateTime(1990, 4, 15),
      gender: Gender.male,
      heightCm: 172,
      weightKg: 72.5,
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
      type: GoalType.lose,
      targetWeightKg: 68,
      targetDate: DateTime(2026, 10, 1),
    ),
  );
  await controller.completeOnboarding();

  final now = DateTime.now();
  controller.exerciseEntries.addAll([
    ExerciseEntry(
      id: 'ex-1',
      name: 'ランニング',
      durationMin: 30,
      burnedKcal: 280,
      loggedAt: now.subtract(const Duration(hours: 2)),
    ),
    ExerciseEntry(
      id: 'ex-2',
      name: '筋トレ',
      durationMin: 45,
      burnedKcal: 210,
      loggedAt: now.subtract(const Duration(hours: 5)),
    ),
    ExerciseEntry(
      id: 'ex-3',
      name: 'ウォーキング',
      durationMin: 20,
      burnedKcal: 95,
      loggedAt: now.subtract(const Duration(days: 1, hours: 3)),
    ),
  ]);

  controller.foodEntries.addAll([
    FoodEntry(
      id: 'food-1',
      name: 'サラダチキン',
      kcalPerUnit: 428,
      proteinPerUnit: 50,
      fatPerUnit: 8,
      carbPerUnit: 2,
      baseAmount: 100,
      unitType: FoodUnitType.g,
      quantity: 1,
      loggedAt: now.subtract(const Duration(hours: 1)),
    ),
    FoodEntry(
      id: 'food-2',
      name: '玄米おにぎり',
      kcalPerUnit: 586,
      proteinPerUnit: 12,
      fatPerUnit: 4,
      carbPerUnit: 120,
      baseAmount: 1,
      unitType: FoodUnitType.piece,
      quantity: 1,
      loggedAt: now.subtract(const Duration(hours: 4)),
    ),
    FoodEntry(
      id: 'food-3',
      name: 'オートミール',
      kcalPerUnit: 150,
      proteinPerUnit: 5,
      fatPerUnit: 3,
      carbPerUnit: 27,
      baseAmount: 40,
      unitType: FoodUnitType.g,
      quantity: 1,
      sourceType: FoodEntrySource.manual,
      loggedAt: now.subtract(const Duration(days: 1, hours: 2)),
    ),
  ]);

  controller.refreshDailySummary();
  return controller;
}

MockAuthenticationRepository createPrototypeUi5AuthRepository() {
  return MockAuthenticationRepository(
    currentUser: const AuthUser(
      id: prototypeUi5UserId,
      email: 'prototype@example.com',
    ),
  );
}
