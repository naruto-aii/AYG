import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/services/saved_food_entry_builder.dart';
import 'package:ayg/utils/saved_food_base_serving_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 20);

  SavedFood food({
    double baseAmount = 100,
    String? servingUnitLabel = 'g',
    double kcal = 380,
  }) {
    return SavedFood(
      foodId: 'food-1',
      ownerUserId: 'user-a',
      name: 'オートミール',
      normalizedName: 'オートミール',
      baseAmount: baseAmount,
      unitType: FoodUnitType.g,
      servingUnitLabel: servingUnitLabel,
      kcalPerBase: kcal,
      proteinPerBase: 13,
      fatPerBase: 7,
      carbPerBase: 69,
      sourceType: FoodSourceType.manual,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('SavedFoodBaseServingFormat', () {
    test('formats integer quantity without decimal point', () {
      expect(SavedFoodBaseServingFormat.formatQuantity(100), '100');
      expect(SavedFoodBaseServingFormat.formatQuantity(1), '1');
      expect(SavedFoodBaseServingFormat.formatQuantity(0.5), '0.5');
    });

    test('shows unset label for legacy foods', () {
      final legacy = food(servingUnitLabel: null);
      expect(legacy.baseServingDefined, isFalse);
      expect(
        SavedFoodBaseServingFormat.formatSavedFood(legacy),
        SavedFoodBaseServingFormat.unsetLabel,
      );
    });

    test('formats per serving label', () {
      expect(
        SavedFoodBaseServingFormat.formatSavedFood(food()),
        '100gあたり',
      );
      expect(
        SavedFoodBaseServingFormat.formatSavedFood(
          food(baseAmount: 1, servingUnitLabel: '缶'),
        ),
        '1缶あたり',
      );
    });
  });

  group('SavedFoodEntryBuilder scaled nutrients', () {
    const builder = SavedFoodEntryBuilder();

    test('scales nutrients by consumed / base ratio', () {
      final scaled = builder.scaledNutrients(
        food: food(),
        consumedQuantity: 50,
      );

      expect(scaled['kcal'], 190);
      expect(scaled['protein'], 6.5);
      expect(scaled['fat'], 3.5);
      expect(scaled['carb'], 34.5);
    });
  });
}
