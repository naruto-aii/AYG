import 'package:ayg/database/entity_mapper.dart';
import 'package:ayg/database/schemas.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_entry_source.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/meal_template.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/services/local_user_data_clearer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isar_test_helper.dart';

SavedFood _sampleSavedFood({
  required String ownerUserId,
  required String foodId,
}) {
  final now = DateTime(2026, 7, 1);
  return SavedFood(
    foodId: foodId,
    ownerUserId: ownerUserId,
    name: 'Sample',
    normalizedName: 'sample',
    baseAmount: 100,
    unitType: FoodUnitType.g,
    kcalPerBase: 120,
    createdAt: now,
    updatedAt: now,
  );
}

MealTemplate _sampleTemplate({
  required String ownerUserId,
  required String templateId,
}) {
  final now = DateTime(2026, 7, 1);
  return MealTemplate(
    templateId: templateId,
    ownerUserId: ownerUserId,
    name: 'Breakfast',
    normalizedName: 'breakfast',
    totalKcal: 300,
    totalProteinG: 20,
    totalFatG: 10,
    totalCarbG: 30,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('FoodEntry Isar compatibility', () {
    test('reads legacy entity with quantity only', () async {
      final harness = await setUpIsarHarness();
      final loggedAt = DateTime(2025, 6, 1, 8);

      await harness.isar.writeTxn(() async {
        await harness.isar.foodEntryEntitys.put(
          FoodEntryEntity()
            ..entryId = 'legacy-1'
            ..name = 'legacy rice'
            ..kcalPerUnit = 180
            ..proteinPerUnit = null
            ..fatPerUnit = 2.5
            ..carbPerUnit = 30
            ..quantity = 2.25
            ..loggedAt = loggedAt,
        );
      });

      final loaded = (await harness.foodRepository.loadAll()).single;

      expect(loaded.baseAmount, 1);
      expect(loaded.unitType, FoodUnitType.serving);
      expect(loaded.consumedAmount, 2.25);
      expect(loaded.quantity, 2.25);
      expect(loaded.totalKcal, 180 * 2.25);
      expect(loaded.totalProteinG, 0);
      expect(loaded.mealGroupId, isNull);
    });

    test('roundtrips new consumption fields without changing totals', () async {
      final harness = await setUpIsarHarness();
      const beforeTotal = 75.0;

      final original = FoodEntry(
        id: 'new-1',
        name: 'cabbage',
        kcalPerBase: 50,
        proteinPerBase: 2.5,
        baseAmount: 100,
        unitType: FoodUnitType.g,
        consumedAmount: 150,
        sourceType: FoodEntrySource.manual,
        loggedAt: DateTime(2026, 3, 1),
      );
      expect(original.totalKcal, beforeTotal);

      await harness.foodRepository.save(original);
      final loaded = (await harness.foodRepository.loadAll()).single;

      expect(loaded.baseAmount, 100);
      expect(loaded.consumedAmount, 150);
      expect(loaded.quantity, 1.5);
      expect(loaded.totalKcal, beforeTotal);
    });

    test('persists meal group metadata', () async {
      final harness = await setUpIsarHarness();

      await harness.foodRepository.save(
        FoodEntry(
          id: 'group-1',
          name: 'template item',
          kcalPerBase: 100,
          baseAmount: 1,
          consumedAmount: 1,
          mealGroupId: 'group-a',
          mealGroupName: 'Breakfast set',
          sortOrder: 2,
          loggedAt: DateTime(2026, 4, 1),
        ),
      );

      final loaded = (await harness.foodRepository.loadAll()).single;
      expect(loaded.mealGroupId, 'group-a');
      expect(loaded.mealGroupName, 'Breakfast set');
      expect(loaded.sortOrder, 2);
    });

    test('entity mapper keeps legacy quantity column in sync', () async {
      final entry = FoodEntry(
        id: 'sync-1',
        name: 'sync',
        kcalPerBase: 90,
        baseAmount: 200,
        unitType: FoodUnitType.g,
        consumedAmount: 100,
        loggedAt: DateTime(2026, 1, 1),
      );

      final entity = EntityMapper.toFoodEntryEntity(entry);
      expect(entity.quantity, 0.5);
      expect(entity.baseAmount, 200);
      expect(entity.consumedAmount, 100);
    });
  });

  group('LocalUserDataClearer', () {
    test('clears saved foods and meal templates', () async {
      final harness = await setUpIsarHarness();
      final clearer = LocalUserDataClearer(
        isar: harness.isar,
        userRepository: harness.userRepository,
        settingsRepository: harness.settingsRepository,
        foodRepository: harness.foodRepository,
        exerciseRepository: harness.exerciseRepository,
        weightRepository: harness.weightRepository,
        savedFoodRepository: harness.savedFoodRepository,
        mealTemplateRepository: harness.mealTemplateRepository,
      );

      await harness.savedFoodRepository.save(
        _sampleSavedFood(ownerUserId: 'user-a', foodId: 'food-a'),
      );
      await harness.mealTemplateRepository.save(
        _sampleTemplate(ownerUserId: 'user-a', templateId: 'tmpl-a'),
      );

      await clearer.clearAll();

      expect(await harness.savedFoodRepository.getAllOwn('user-a'), isEmpty);
      expect(await harness.mealTemplateRepository.getAll('user-a'), isEmpty);
    });
  });
}
