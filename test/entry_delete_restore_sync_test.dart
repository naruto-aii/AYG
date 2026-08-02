import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/models/weight_entry.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/services/alcohol_nutrition_calculator.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isar_test_helper.dart';
import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  group('Entry delete and restore sync', () {
    late IsarTestHarness harness;
    late AppController controller;
    late MockDataSyncRepository dataSyncRepository;

    setUp(() async {
      harness = await IsarTestHarness.create();
      dataSyncRepository = MockDataSyncRepository();
      controller = AppController(
        healthRepository: MockHealthRepository(isAvailable: false),
        authenticationRepository: MockAuthenticationRepository(
          currentUser: const AuthUser(
            id: 'test-user-id',
            email: 'test@example.com',
          ),
        ),
        dataSyncRepository: dataSyncRepository,
        userRepository: harness.userRepository,
        settingsRepository: harness.settingsRepository,
        foodRepository: harness.foodRepository,
        exerciseRepository: harness.exerciseRepository,
        alcoholRepository: harness.alcoholRepository,
        weightRepository: harness.weightRepository,
        savedFoodRepository: harness.savedFoodRepository,
      );
      controller.profile = UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 170,
        weightKg: 70,
      );
      controller.goal = Goal(
        type: GoalType.maintain,
        targetWeightKg: 70,
        targetDate: DateTime(2026, 12, 31),
      );
      controller.nutritionSettings = const NutritionSettings(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
      );
    });

    tearDown(() async {
      controller.dispose();
      await harness.dispose();
    });

    ExerciseEntry sampleExercise({String id = 'ex-1'}) {
      return ExerciseEntry(
        id: id,
        name: 'Walk',
        durationMin: 30,
        burnedKcal: 200,
        loggedAt: DateTime(2026, 7, 20, 12),
        netKcal: 150,
        grossKcal: 200,
      );
    }

    WeightEntry sampleWeight({String id = 'wt-1'}) {
      return WeightEntry(
        id: id,
        weightKg: 68.5,
        recordedAt: DateTime(2026, 7, 20, 8),
        source: WeightSource.manual,
      );
    }

    group('exercise', () {
      test('delete removes remote before local and survives pull', () async {
        await controller.addExercise(sampleExercise());
        await controller.deleteExercise('ex-1');

        expect(dataSyncRepository.deletedExerciseEntryIds, ['ex-1']);
        expect(controller.exerciseEntries, isEmpty);

        await harness.exerciseRepository.saveAll(const []);
        await controller.loadPersistedState();
        expect(controller.exerciseEntries, isEmpty);
      });

      test('restore after delete pushes remote and survives pull', () async {
        final entry = sampleExercise();
        await controller.addExercise(entry);
        await controller.deleteExercise('ex-1');
        dataSyncRepository.pushLocalToRemoteCalled = false;

        await controller.restoreExerciseEntry(entry);

        expect(dataSyncRepository.pushLocalToRemoteCalled, isTrue);
        expect(controller.exerciseEntries, hasLength(1));
        await controller.loadPersistedState();
        expect(controller.exerciseEntries, hasLength(1));
      });

      test('remote delete failure keeps local entry', () async {
        dataSyncRepository.failDeleteExerciseEntry = true;
        await controller.addExercise(sampleExercise());

        await expectLater(
          controller.deleteExercise('ex-1'),
          throwsA(isA<StateError>()),
        );
        expect(await harness.exerciseRepository.loadAll(), hasLength(1));
      });
    });

    group('weight', () {
      test('delete removes remote before local and survives pull', () async {
        await harness.weightRepository.save(sampleWeight());
        await controller.loadPersistedState();
        expect(controller.weightEntries, hasLength(1));

        await controller.deleteWeightEntry('wt-1');

        expect(dataSyncRepository.deletedWeightEntryIds, ['wt-1']);
        expect(controller.weightEntries, isEmpty);

        await harness.weightRepository.clearAll();
        await controller.loadPersistedState();
        expect(controller.weightEntries, isEmpty);
      });

      test('restore after delete pushes remote and survives pull', () async {
        final entry = sampleWeight();
        await harness.weightRepository.save(entry);
        await controller.loadPersistedState();
        await controller.deleteWeightEntry('wt-1');
        dataSyncRepository.pushLocalToRemoteCalled = false;

        await controller.restoreWeightEntry(entry);

        expect(dataSyncRepository.pushLocalToRemoteCalled, isTrue);
        expect(controller.weightEntries, hasLength(1));
        await controller.loadPersistedState();
        expect(controller.weightEntries, hasLength(1));
      });

      test('remote delete failure keeps local entry', () async {
        dataSyncRepository.failDeleteWeightEntry = true;
        await harness.weightRepository.save(sampleWeight());
        await controller.loadPersistedState();

        await expectLater(
          controller.deleteWeightEntry('wt-1'),
          throwsA(isA<StateError>()),
        );
        expect(await harness.weightRepository.loadAll(), hasLength(1));
      });
    });
  });

  group('Alcohol edit recalculation', () {
    test('20mL to 500mL recalculates derived values when not manual', () {
      final small = AlcoholNutritionCalculator.resolve(
        amount: 20,
        unit: 'ml',
        alcoholPercentage: 5,
      );
      final large = AlcoholNutritionCalculator.resolve(
        amount: 500,
        unit: 'ml',
        alcoholPercentage: 5,
      );

      expect(large.pureAlcoholGrams, 20);
      expect(large.totalCalories, 140);
      expect(large.totalCalories, greaterThan(small.totalCalories));
    });

    test('manual total calories are preserved when explicitly provided', () {
      final manual = AlcoholNutritionCalculator.resolve(
        amount: 500,
        unit: 'ml',
        alcoholPercentage: 5,
        totalCaloriesInput: 220,
      );

      expect(manual.totalCalories, 220);
      expect(manual.totalCaloriesIsEstimated, isFalse);
      expect(manual.alcoholCalories, 140);
    });
  });
}
