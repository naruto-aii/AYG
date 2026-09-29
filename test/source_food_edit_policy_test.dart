import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/services/alcohol_nutrition_calculator.dart';
import 'package:ayg/services/source_food_edit_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceFoodEditPolicy', () {
    FoodEntry linkedEntry({double consumed = 1, double kcal = 200}) {
      return FoodEntry(
        id: 'f1',
        name: 'Rice',
        kcalPerBase: kcal,
        baseAmount: 100,
        unitType: FoodUnitType.g,
        consumedAmount: consumed,
        savedFoodId: 'sf-1',
        sourceFoodOwnerUserId: 'user-1',
        loggedAt: DateTime(2026, 7, 20),
      );
    }

    test('quantity-only change does not affect source food', () {
      final original = linkedEntry(consumed: 1);
      final updated = linkedEntry(consumed: 2);

      expect(
        SourceFoodEditPolicy.affectsSourceFood(
          original: original,
          updated: updated,
        ),
        isFalse,
      );
      expect(
        SourceFoodEditPolicy.isConsumptionOnlyChange(
          original: original,
          updated: updated,
        ),
        isTrue,
      );
    });

    test('kcal per base change affects source food', () {
      final original = linkedEntry(kcal: 200);
      final updated = linkedEntry(kcal: 250);

      expect(
        SourceFoodEditPolicy.affectsSourceFood(
          original: original,
          updated: updated,
        ),
        isTrue,
      );
    });
  });

  group('Alcohol edit recalculation', () {
    test('20mL to 500mL recalculates when total calories not manual', () {
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

      expect(small.pureAlcoholGrams, closeTo(0.8, 0.001));
      expect(large.pureAlcoholGrams, 20);
      expect(large.totalCalories, 140);
      expect(large.totalCalories, greaterThan(small.totalCalories));
    });

    test('stale manual total is ignored when not manually edited flag', () {
      final recalculated = AlcoholNutritionCalculator.resolve(
        amount: 500,
        unit: 'ml',
        alcoholPercentage: 5,
        totalCaloriesInput: null,
      );
      final stale = AlcoholNutritionCalculator.resolve(
        amount: 500,
        unit: 'ml',
        alcoholPercentage: 5,
        totalCaloriesInput: 5.6,
      );

      expect(recalculated.totalCalories, 140);
      expect(stale.totalCalories, 5.6);
    });
  });
}
