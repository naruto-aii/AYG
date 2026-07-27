import '../models/food_entry.dart';
import '../models/food_entry_source.dart';
import '../models/food_unit_type.dart';
import '../models/saved_food.dart';
import '../models/saved_food.dart';

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
    return formatBaseAmountLabel(
      baseAmount: food.baseAmount,
      unitType: food.unitType,
    );
  }

  String formatBaseAmountLabel({
    required double baseAmount,
    required FoodUnitType unitType,
  }) {
    return '${baseAmount.toStringAsFixed(baseAmount.truncateToDouble() == baseAmount ? 0 : 1)}${unitType.label}あたり';
  }
}
