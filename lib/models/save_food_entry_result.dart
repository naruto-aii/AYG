import 'food_entry.dart';
import 'saved_food.dart';
import 'saved_food_persistence_error.dart';

/// 食事保存 + 任意の食品マスター保存結果。
class SaveFoodEntryResult {
  const SaveFoodEntryResult({
    required this.foodEntrySaved,
    this.entry,
    this.savedFood,
    this.savedFoodSaved = false,
    this.savedFoodErrorMessage,
    this.savedFoodErrorCode,
  });

  final bool foodEntrySaved;
  final FoodEntry? entry;
  final SavedFood? savedFood;
  final bool savedFoodSaved;
  final String? savedFoodErrorMessage;
  final SavedFoodErrorCode? savedFoodErrorCode;

  bool get isFullSuccess => foodEntrySaved && savedFoodErrorMessage == null;
}
