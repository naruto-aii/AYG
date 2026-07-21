import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/app_settings.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/health_snapshot.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/models/weight_entry.dart';
import 'package:ayg/state/app_controller.dart';

import 'helpers/isar_test_helper.dart';

void main() {
  group('Isar persistence', () {
    test('UserRepository saves and loads profile and goal', () async {
      final harness = await setUpIsarHarness();

      await harness.userRepository.saveProfile(
        UserProfile(
          birthDate: DateTime(1992, 5, 1),
          gender: Gender.male,
          heightCm: 172,
          weightKg: 68,
        ),
      );
      await harness.userRepository.saveGoal(
        Goal(
          type: GoalType.lose,
          targetWeightKg: 65,
          targetDate: DateTime(2026, 12, 31),
        ),
      );

      expect(await harness.userRepository.loadProfile(), isNotNull);
      expect((await harness.userRepository.loadGoal())?.type, GoalType.lose);
    });

    test(
      'SettingsRepository saves nutrition settings and health snapshot',
      () async {
        final harness = await setUpIsarHarness();

        await harness.settingsRepository.saveNutritionSettings(
          const NutritionSettings(useHealthIntegration: true),
        );
        await harness.settingsRepository.saveHealthSnapshot(
          const HealthSnapshot(activeEnergyBurnedKcal: 350, weightKg: 67),
        );
        await harness.settingsRepository.saveAppSettings(
          const AppSettings(onboardingComplete: true),
        );

        expect(
          (await harness.settingsRepository.loadNutritionSettings())
              ?.useHealthIntegration,
          isTrue,
        );
        expect(
          (await harness.settingsRepository.loadHealthSnapshot())
              ?.activeEnergyBurnedKcal,
          350,
        );
        expect(
          (await harness.settingsRepository.loadAppSettings())
              .onboardingComplete,
          isTrue,
        );
      },
    );

    test('FoodRepository and ExerciseRepository persist entries', () async {
      final harness = await setUpIsarHarness();
      final loggedAt = DateTime(2026, 7, 21, 12);

      await harness.foodRepository.save(
        FoodEntry(
          id: 'food-1',
          name: 'Rice',
          kcalPerUnit: 200,
          quantity: 1,
          loggedAt: loggedAt,
        ),
      );
      await harness.exerciseRepository.save(
        ExerciseEntry(
          id: 'exercise-1',
          name: 'Run',
          durationMin: 30,
          burnedKcal: 250,
          loggedAt: loggedAt,
        ),
      );

      expect(await harness.foodRepository.loadAll(), hasLength(1));
      expect(await harness.exerciseRepository.loadAll(), hasLength(1));
    });

    test('WeightRepository persists weight entries', () async {
      final harness = await setUpIsarHarness();

      await harness.weightRepository.save(
        WeightEntry(
          id: 'weight-1',
          weightKg: 70,
          recordedAt: DateTime(2026, 7, 21),
          source: WeightSource.manual,
        ),
      );

      final entries = await harness.weightRepository.loadAll();
      expect(entries, hasLength(1));
      expect(entries.first.weightKg, 70);
    });
  });

  group('AppController persistence', () {
    test('loadPersistedState restores saved data', () async {
      final harness = await setUpIsarHarness();

      await harness.userRepository.saveProfile(
        UserProfile(
          birthDate: DateTime(1990, 1, 1),
          gender: Gender.female,
          heightCm: 160,
          weightKg: 55,
        ),
      );
      await harness.userRepository.saveGoal(
        Goal(
          type: GoalType.maintain,
          targetWeightKg: 55,
          targetDate: DateTime(2026, 12, 31),
        ),
      );
      await harness.settingsRepository.saveNutritionSettings(
        const NutritionSettings(
          useHealthIntegration: false,
          activityLevel: ActivityLevel.moderate,
        ),
      );
      await harness.settingsRepository.saveHealthSnapshot(
        const HealthSnapshot(activeEnergyBurnedKcal: 400),
      );

      final controller = AppController(
        userRepository: harness.userRepository,
        settingsRepository: harness.settingsRepository,
        foodRepository: harness.foodRepository,
        exerciseRepository: harness.exerciseRepository,
        weightRepository: harness.weightRepository,
      );

      await controller.loadPersistedState();

      expect(controller.profile?.weightKg, 55);
      expect(controller.goal?.type, GoalType.maintain);
      expect(
        controller.nutritionSettings?.activityLevel,
        ActivityLevel.moderate,
      );
      expect(controller.healthSnapshot.activeEnergyBurnedKcal, 400);
    });
  });
}
