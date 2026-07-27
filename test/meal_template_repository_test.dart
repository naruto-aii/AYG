import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/meal_template.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isar_test_helper.dart';

void main() {
  group('MealTemplateRepository', () {
    test('saves template with ordered items and snapshots', () async {
      final harness = await setUpIsarHarness();
      final now = DateTime(2026, 7, 20);

      final template = MealTemplate(
        templateId: 'tmpl-1',
        ownerUserId: 'user-a',
        name: 'Morning Set',
        normalizedName: 'morning set',
        totalKcal: 400,
        totalProteinG: 25,
        totalFatG: 12,
        totalCarbG: 45,
        createdAt: now,
        updatedAt: now,
      );

      await harness.mealTemplateRepository.save(template);
      await harness.mealTemplateRepository.replaceItems(
        ownerUserId: 'user-a',
        templateId: 'tmpl-1',
        items: [
          MealTemplateItem(
            itemId: 'item-2',
            name: 'Egg',
            baseAmount: 50,
            unitType: FoodUnitType.g,
            kcalPerBase: 70,
            consumedAmount: 100,
            sortOrder: 2,
            snapshotSavedAt: now,
          ),
          MealTemplateItem(
            itemId: 'item-1',
            savedFoodId: 'deleted-food',
            sourceOwnerUserId: 'other-user',
            name: 'Rice',
            baseAmount: 150,
            unitType: FoodUnitType.g,
            kcalPerBase: 180,
            consumedAmount: 150,
            sortOrder: 1,
            itemDependencyStatus: ItemDependencyStatus.sourceDeleted,
            snapshotSavedAt: now,
          ),
        ],
      );

      final loadedItems = await harness.mealTemplateRepository.getItems(
        ownerUserId: 'user-a',
        templateId: 'tmpl-1',
      );

      expect(loadedItems, hasLength(2));
      expect(loadedItems.first.itemId, 'item-1');
      expect(loadedItems.first.name, 'Rice');
      expect(loadedItems.first.savedFoodId, 'deleted-food');
      expect(loadedItems.first.totalKcal, 180);
      expect(loadedItems.last.sortOrder, 2);
    });

    test('reads items without saved food reference', () async {
      final harness = await setUpIsarHarness();
      final now = DateTime(2026, 7, 21);

      await harness.mealTemplateRepository.save(
        MealTemplate(
          templateId: 'tmpl-2',
          ownerUserId: 'user-a',
          name: 'Snack',
          normalizedName: 'snack',
          totalKcal: 100,
          totalProteinG: 5,
          totalFatG: 2,
          totalCarbG: 10,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await harness.mealTemplateRepository.replaceItems(
        ownerUserId: 'user-a',
        templateId: 'tmpl-2',
        items: [
          MealTemplateItem(
            itemId: 'item-only',
            name: 'Standalone',
            baseAmount: 1,
            unitType: FoodUnitType.serving,
            kcalPerBase: 100,
            consumedAmount: 1,
            sortOrder: 1,
            snapshotSavedAt: now,
          ),
        ],
      );

      final items = await harness.mealTemplateRepository.getItems(
        ownerUserId: 'user-a',
        templateId: 'tmpl-2',
      );
      expect(items.single.savedFoodId, isNull);
      expect(items.single.name, 'Standalone');
    });

    test('search and softDelete', () async {
      final harness = await setUpIsarHarness();
      final now = DateTime(2026, 7, 22);

      await harness.mealTemplateRepository.save(
        MealTemplate(
          templateId: 'tmpl-search',
          ownerUserId: 'user-a',
          name: 'Lunch Box',
          normalizedName: 'lunch box',
          totalKcal: 500,
          totalProteinG: 30,
          totalFatG: 15,
          totalCarbG: 60,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final results = await harness.mealTemplateRepository.search(
        ownerUserId: 'user-a',
        query: 'lunch',
      );
      expect(results, hasLength(1));

      await harness.mealTemplateRepository.softDelete(
        ownerUserId: 'user-a',
        templateId: 'tmpl-search',
        deletedAt: now,
      );
      expect(await harness.mealTemplateRepository.getAll('user-a'), isEmpty);
    });

    test('clearAll removes templates and items', () async {
      final harness = await setUpIsarHarness();
      final now = DateTime(2026, 7, 23);

      await harness.mealTemplateRepository.save(
        MealTemplate(
          templateId: 'tmpl-clear',
          ownerUserId: 'user-a',
          name: 'Clear',
          normalizedName: 'clear',
          totalKcal: 100,
          totalProteinG: 5,
          totalFatG: 2,
          totalCarbG: 10,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await harness.mealTemplateRepository.replaceItems(
        ownerUserId: 'user-a',
        templateId: 'tmpl-clear',
        items: [
          MealTemplateItem(
            itemId: 'item-clear',
            name: 'Item',
            baseAmount: 1,
            unitType: FoodUnitType.serving,
            consumedAmount: 1,
            sortOrder: 1,
            snapshotSavedAt: now,
          ),
        ],
      );

      await harness.mealTemplateRepository.clearAll();
      expect(await harness.mealTemplateRepository.getAll('user-a'), isEmpty);
    });
  });
}
