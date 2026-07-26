import 'package:ayg/models/food_entry_source.dart';
import 'package:ayg/services/macro_nutrition_consistency_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MacroNutritionConsistencyPolicy', () {
    test('manual uses manual mode', () {
      expect(
        MacroNutritionConsistencyPolicy.initialModeFor(FoodEntrySource.manual),
        MacroNutritionConsistencyMode.manual,
      );
    });

    test('openFoodFacts uses preserveExternal mode', () {
      expect(
        MacroNutritionConsistencyPolicy.initialModeFor(
          FoodEntrySource.openFoodFacts,
        ),
        MacroNutritionConsistencyMode.preserveExternal,
      );
    });

    test('savedFood and template use preserveExternal mode', () {
      expect(
        MacroNutritionConsistencyPolicy.initialModeFor(
          FoodEntrySource.savedFood,
        ),
        MacroNutritionConsistencyMode.preserveExternal,
      );
      expect(
        MacroNutritionConsistencyPolicy.initialModeFor(
          FoodEntrySource.template,
        ),
        MacroNutritionConsistencyMode.preserveExternal,
      );
    });

    test('resolveSaveSourceType keeps source when not edited', () {
      expect(
        MacroNutritionConsistencyPolicy.resolveSaveSourceType(
          initialSourceType: FoodEntrySource.openFoodFacts,
          nutritionEditedByUser: false,
        ),
        FoodEntrySource.openFoodFacts,
      );
    });

    test('resolveSaveSourceType switches to manual when edited', () {
      expect(
        MacroNutritionConsistencyPolicy.resolveSaveSourceType(
          initialSourceType: FoodEntrySource.openFoodFacts,
          nutritionEditedByUser: true,
        ),
        FoodEntrySource.manual,
      );
      expect(
        MacroNutritionConsistencyPolicy.resolveSaveSourceType(
          initialSourceType: FoodEntrySource.savedFood,
          nutritionEditedByUser: true,
        ),
        FoodEntrySource.manual,
      );
    });
  });
}
