import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/duplicate_saved_food_action.dart';
import 'package:ayg/models/duplicate_saved_food_resolution.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_entry_source.dart';
import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/models/saved_food_draft.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isar_test_helper.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  group('AppController saved food', () {
    late IsarTestHarness harness;
    late AppController controller;

    setUp(() async {
      harness = await IsarTestHarness.create();
      controller = AppController(
        healthRepository: MockHealthRepository(isAvailable: false),
        userRepository: harness.userRepository,
        settingsRepository: harness.settingsRepository,
        foodRepository: harness.foodRepository,
        exerciseRepository: harness.exerciseRepository,
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

    Future<SavedFood> seedFood({
      required String id,
      required String name,
      double baseAmount = 100,
      FoodUnitType unitType = FoodUnitType.g,
      double kcal = 200,
    }) async {
      final now = DateTime(2026, 7, 20);
      final food = SavedFood(
        foodId: id,
        ownerUserId: AppController.localOwnerUserId,
        name: name,
        normalizedName: name.toLowerCase(),
        baseAmount: baseAmount,
        unitType: unitType,
        kcalPerBase: kcal,
        proteinPerBase: 10,
        fatPerBase: 5,
        carbPerBase: 20,
        sourceType: FoodSourceType.manual,
        createdAt: now,
        updatedAt: now,
      );
      await harness.savedFoodRepository.savePrivate(food);
      return food;
    }

    FoodEntry sampleEntry({String? savedFoodId}) {
      return FoodEntry(
        id: 'entry-1',
        name: 'テスト',
        kcalPerBase: 200,
        proteinPerBase: 10,
        fatPerBase: 5,
        carbPerBase: 20,
        baseAmount: 100,
        unitType: FoodUnitType.g,
        consumedAmount: 150,
        sourceType: FoodEntrySource.savedFood,
        savedFoodId: savedFoodId,
        sourceFoodOwnerUserId: savedFoodId == null
            ? null
            : AppController.localOwnerUserId,
        loggedAt: DateTime(2026, 7, 20, 12),
      );
    }

    test('createSavedFood saves private food locally', () async {
      final created = await controller.createSavedFood(
        const SavedFoodDraft(
          name: '鶏むね',
          baseAmount: 100,
          unitType: FoodUnitType.g,
          kcalPerBase: 165,
          proteinPerBase: 31,
          fatPerBase: 3,
          carbPerBase: 0,
        ),
      );

      final loaded = await harness.savedFoodRepository.getOwn(
        ownerUserId: AppController.localOwnerUserId,
        foodId: created.foodId,
      );
      expect(loaded, isNotNull);
      expect(loaded!.name, '鶏むね');
    });

    test('searchOwnSavedFoods excludes deleted foods', () async {
      await seedFood(id: 'food-1', name: 'Active');
      await seedFood(id: 'food-2', name: 'Deleted');
      await controller.deleteSavedFood('food-2');

      final results = await controller.searchOwnSavedFoods('');
      expect(results.map((food) => food.foodId), ['food-1']);
    });

    test('saveFoodEntryWithOptionalSavedFood links existing duplicate', () async {
      final existing = await seedFood(id: 'dup', name: 'Same Name');
      final entry = sampleEntry();

      final result = await controller.saveFoodEntryWithOptionalSavedFood(
        entry: entry,
        saveAsFood: true,
        duplicateResolution: DuplicateSavedFoodResolution(
          action: DuplicateSavedFoodAction.useExisting,
          draft: SavedFoodDraft(
            name: existing.name,
            baseAmount: existing.baseAmount,
            unitType: existing.unitType,
            kcalPerBase: existing.kcalPerBase,
            proteinPerBase: existing.proteinPerBase,
            fatPerBase: existing.fatPerBase,
            carbPerBase: existing.carbPerBase,
          ),
          existingFood: existing,
        ),
      );

      expect(result.foodEntrySaved, isTrue);
      expect(result.entry?.savedFoodId, 'dup');
      expect(
        await harness.savedFoodRepository.searchOwn(
          ownerUserId: AppController.localOwnerUserId,
          query: '',
        ),
        hasLength(1),
      );
    });

    test('saveFoodEntryWithOptionalSavedFood keeps entry when saved food fails',
        () async {
      final entry = sampleEntry();
      final partialController = AppController(
        healthRepository: MockHealthRepository(isAvailable: false),
        foodRepository: harness.foodRepository,
        savedFoodRepository: null,
      );
      addTearDown(partialController.dispose);

      final result = await partialController.saveFoodEntryWithOptionalSavedFood(
        entry: entry,
        saveAsFood: true,
        savedFoodDraft: const SavedFoodDraft(
          name: 'fail',
          baseAmount: 100,
          unitType: FoodUnitType.g,
          kcalPerBase: 1,
          proteinPerBase: 1,
          fatPerBase: 1,
          carbPerBase: 1,
        ),
      );

      expect(result.foodEntrySaved, isTrue);
      expect(result.savedFoodSaved, isFalse);
      expect(result.savedFoodErrorMessage, isNotNull);
      expect(partialController.foodEntries, hasLength(1));
    });

    test('updating saved food does not mutate past food entries', () async {
      final food = await seedFood(id: 'food-1', name: 'Original');
      await controller.addFood(
        sampleEntry(savedFoodId: food.foodId),
      );

      await controller.updateSavedFood(food.copyWith(name: 'Updated'));

      expect(controller.foodEntries.single.name, 'テスト');
      final reloaded = await harness.savedFoodRepository.getOwn(
        ownerUserId: AppController.localOwnerUserId,
        foodId: food.foodId,
      );
      expect(reloaded!.name, 'Updated');
    });

    test('deleteFood recalculates daily totals for saved-food entry', () async {
      final food = await seedFood(id: 'food-1', name: 'Food');
      await controller.addFood(
        sampleEntry(savedFoodId: food.foodId),
      );
      controller.refreshDailySummary(
        referenceDate: DateTime(2026, 7, 20, 18),
      );
      expect(controller.summary!.intakeKcal, 300);

      await controller.deleteFood('entry-1');
      controller.refreshDailySummary(
        referenceDate: DateTime(2026, 7, 20, 18),
      );
      expect(controller.summary!.intakeKcal, 0);
    });
  });
}
