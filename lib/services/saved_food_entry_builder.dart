import '../models/food_entry.dart';
import '../models/food_entry_source.dart';
import '../models/food_unit_type.dart';
import '../models/saved_food.dart';
import '../utils/saved_food_base_serving_format.dart';

/// SavedFood から FoodEntry スナップショットを組み立てる。
class SavedFoodEntryBuilder {
  const SavedFoodEntryBuilder();

  FoodEntry buildFromSavedFood({
    required SavedFood food,
    required String entryId,
    required double consumedAmount,
    required DateTime loggedAt,
  }) {
    return FoodEntry(
      id: entryId,
      name: food.name,
      kcalPerBase: food.kcalPerBase,
      proteinPerBase: food.proteinPerBase,
      fatPerBase: food.fatPerBase,
      carbPerBase: food.carbPerBase,
      baseAmount: food.baseAmount,
      unitType: food.unitType,
      consumedAmount: consumedAmount,
      sourceType: FoodEntrySource.savedFood,
      savedFoodId: food.foodId,
      sourceFoodOwnerUserId: food.ownerUserId,
      sourceSavedFoodVersion: food.version,
      loggedAt: loggedAt,
    );
  }

  String formatBaseLabel(SavedFood food) {
    return SavedFoodBaseServingFormat.formatSavedFood(food);
  }

  String formatBaseAmountLabel({
    required double baseAmount,
    required FoodUnitType unitType,
    String? servingUnitLabel,
  }) {
    if (servingUnitLabel != null && servingUnitLabel.trim().isNotEmpty) {
      return SavedFoodBaseServingFormat.formatPerBaseLabel(
        baseServingDefined: baseAmount > 0,
        baseAmount: baseAmount,
        baseUnit: servingUnitLabel,
      );
    }
    return '${SavedFoodBaseServingFormat.formatQuantity(baseAmount)}${unitType.label}あたり';
  }

  /// 食べた数量に応じた記録用栄養素（表示用）。
  Map<String, double?> scaledNutrients({
    required SavedFood food,
    required double consumedQuantity,
  }) {
    if (!food.baseServingDefined || food.baseAmount <= 0) {
      return const {};
    }
    final ratio = consumedQuantity / food.baseAmount;
    return {
      'kcal': food.kcalPerBase != null ? food.kcalPerBase! * ratio : null,
      'protein':
          food.proteinPerBase != null ? food.proteinPerBase! * ratio : null,
      'fat': food.fatPerBase != null ? food.fatPerBase! * ratio : null,
      'carb': food.carbPerBase != null ? food.carbPerBase! * ratio : null,
    };
  }
}
