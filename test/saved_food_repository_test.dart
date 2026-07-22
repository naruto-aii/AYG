import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/models/food_status.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isar_test_helper.dart';

void main() {
  group('SavedFoodRepository', () {
    test('CRUD and search by normalized name', () async {
      final harness = await setUpIsarHarness();
      final now = DateTime(2026, 7, 10);

      final food = SavedFood(
        foodId: 'food-1',
        ownerUserId: 'user-a',
        name: 'Chicken Breast',
        normalizedName: 'chicken breast',
        baseAmount: 100,
        unitType: FoodUnitType.g,
        kcalPerBase: 165,
        proteinPerBase: 31,
        visibility: FoodVisibility.private,
        status: FoodStatus.active,
        sourceType: FoodSourceType.manual,
        barcode: '4901234567890',
        useCount: 3,
        lastUsedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await harness.savedFoodRepository.save(food);

      final loaded = await harness.savedFoodRepository.getById(
        ownerUserId: 'user-a',
        foodId: 'food-1',
      );
      expect(loaded, isNotNull);
      expect(loaded!.visibility, FoodVisibility.private);
      expect(loaded.barcode, '4901234567890');
      expect(loaded.useCount, 3);

      final searchResults = await harness.savedFoodRepository.searchOwn(
        ownerUserId: 'user-a',
        query: 'chicken',
      );
      expect(searchResults, hasLength(1));

      final updated = loaded.copyWith(
        useCount: 5,
        lastUsedAt: now.add(const Duration(hours: 1)),
        updatedAt: now.add(const Duration(hours: 1)),
      );
      await harness.savedFoodRepository.update(updated);

      final reloaded = await harness.savedFoodRepository.getById(
        ownerUserId: 'user-a',
        foodId: 'food-1',
      );
      expect(reloaded!.useCount, 5);
    });

    test('softDelete hides food from active queries', () async {
      final harness = await setUpIsarHarness();
      final now = DateTime(2026, 7, 11);

      await harness.savedFoodRepository.save(
        SavedFood(
          foodId: 'food-del',
          ownerUserId: 'user-a',
          name: 'Temp',
          normalizedName: 'temp',
          baseAmount: 100,
          unitType: FoodUnitType.g,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await harness.savedFoodRepository.softDelete(
        ownerUserId: 'user-a',
        foodId: 'food-del',
        deletedAt: now,
      );

      expect(await harness.savedFoodRepository.getAllOwn('user-a'), isEmpty);
      expect(
        await harness.savedFoodRepository.getById(
          ownerUserId: 'user-a',
          foodId: 'food-del',
        ),
        isNotNull,
      );
    });

    test('does not return other owner foods', () async {
      final harness = await setUpIsarHarness();
      final now = DateTime(2026, 7, 12);

      await harness.savedFoodRepository.saveAll([
        SavedFood(
          foodId: 'food-a',
          ownerUserId: 'user-a',
          name: 'A',
          normalizedName: 'a',
          baseAmount: 100,
          unitType: FoodUnitType.g,
          createdAt: now,
          updatedAt: now,
        ),
        SavedFood(
          foodId: 'food-b',
          ownerUserId: 'user-b',
          name: 'B',
          normalizedName: 'b',
          baseAmount: 100,
          unitType: FoodUnitType.g,
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      expect(
        await harness.savedFoodRepository.getAllOwn('user-a'),
        hasLength(1),
      );
      expect(
        await harness.savedFoodRepository.getById(
          ownerUserId: 'user-a',
          foodId: 'food-b',
        ),
        isNull,
      );
    });

    test('clearAll removes all saved foods', () async {
      final harness = await setUpIsarHarness();
      final now = DateTime(2026, 7, 13);

      await harness.savedFoodRepository.save(
        SavedFood(
          foodId: 'food-clear',
          ownerUserId: 'user-a',
          name: 'Clear me',
          normalizedName: 'clear me',
          baseAmount: 100,
          unitType: FoodUnitType.g,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await harness.savedFoodRepository.clearAll();
      expect(await harness.savedFoodRepository.getAllOwn('user-a'), isEmpty);
    });
  });
}
