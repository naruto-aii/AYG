import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_entry_source.dart';
import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/services/saved_food_entry_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = SavedFoodEntryBuilder();
  final now = DateTime(2026, 7, 20, 12);

  SavedFood savedFood({
    required double baseAmount,
    required FoodUnitType unitType,
    double kcal = 200,
  }) {
    return SavedFood(
      foodId: 'food-1',
      ownerUserId: 'user-a',
      name: 'テスト食品',
      normalizedName: 'テスト食品',
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
  }

  group('SavedFoodEntryBuilder', () {
    test('100g -> 150g scales totals', () {
      final entry = builder.buildFromSavedFood(
        food: savedFood(baseAmount: 100, unitType: FoodUnitType.g, kcal: 200),
        entryId: 'entry-1',
        consumedAmount: 150,
        loggedAt: now,
      );

      expect(entry.multiplier, 1.5);
      expect(entry.totalKcal, 300);
      expect(entry.savedFoodId, 'food-1');
      expect(entry.sourceType, FoodEntrySource.savedFood);
    });

    test('1 piece -> 2 pieces scales totals', () {
      final entry = builder.buildFromSavedFood(
        food: savedFood(baseAmount: 1, unitType: FoodUnitType.piece),
        entryId: 'entry-2',
        consumedAmount: 2,
        loggedAt: now,
      );

      expect(entry.multiplier, 2);
      expect(entry.totalKcal, 400);
    });

    test('1 serving -> 0.5 serving scales totals', () {
      final entry = builder.buildFromSavedFood(
        food: savedFood(baseAmount: 1, unitType: FoodUnitType.serving),
        entryId: 'entry-3',
        consumedAmount: 0.5,
        loggedAt: now,
      );

      expect(entry.multiplier, 0.5);
      expect(entry.totalKcal, 100);
    });

    test('snapshot keeps name even if master changes later', () {
      final food = savedFood(baseAmount: 100, unitType: FoodUnitType.g);
      final entry = builder.buildFromSavedFood(
        food: food,
        entryId: 'entry-4',
        consumedAmount: 100,
        loggedAt: now,
      );

      final updatedFood = food.copyWith(name: '変更後');
      expect(entry.name, 'テスト食品');
      expect(updatedFood.name, '変更後');
      expect(entry.name, isNot(updatedFood.name));
    });
  });
}
