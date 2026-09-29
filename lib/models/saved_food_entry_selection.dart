import '../models/food_entry_source.dart';
import '../models/food_source_type.dart';
import '../models/food_unit_type.dart';
import '../models/saved_food.dart';

/// 保存済み食品を食事フォームへ反映するための値。
class SavedFoodEntrySelection {
  const SavedFoodEntrySelection({
    required this.name,
    required this.baseAmount,
    required this.unitType,
    required this.kcalPerBase,
    required this.proteinPerBase,
    required this.fatPerBase,
    required this.carbPerBase,
    required this.savedFoodId,
    required this.sourceFoodOwnerUserId,
    required this.sourceSavedFoodVersion,
    required this.sourceType,
    required this.entrySourceType,
  });

  final String name;
  final double baseAmount;
  final FoodUnitType unitType;
  final double? kcalPerBase;
  final double? proteinPerBase;
  final double? fatPerBase;
  final double? carbPerBase;
  final String savedFoodId;
  final String sourceFoodOwnerUserId;
  final int? sourceSavedFoodVersion;
  final FoodSourceType sourceType;
  final FoodEntrySource entrySourceType;

  factory SavedFoodEntrySelection.fromSavedFood(SavedFood food) {
    return SavedFoodEntrySelection(
      name: food.name,
      baseAmount: food.baseAmount,
      unitType: food.unitType,
      kcalPerBase: food.kcalPerBase,
      proteinPerBase: food.proteinPerBase,
      fatPerBase: food.fatPerBase,
      carbPerBase: food.carbPerBase,
      savedFoodId: food.foodId,
      sourceFoodOwnerUserId: food.ownerUserId,
      sourceSavedFoodVersion: food.version,
      sourceType: food.sourceType,
      entrySourceType: FoodEntrySource.savedFood,
    );
  }
}
