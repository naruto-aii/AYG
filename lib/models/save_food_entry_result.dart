import 'food_entry.dart';
import 'saved_food.dart';

/// 食事保存 + 任意の食品マスター保存結果。
class SaveFoodEntryResult {
  const SaveFoodEntryResult({
    required this.foodEntrySaved,
    this.entry,
    this.savedFood,
    this.savedFoodSaved = false,
    this.savedFoodErrorMessage,
  });

  final bool foodEntrySaved;
  final FoodEntry? entry;
  final SavedFood? savedFood;
  final bool savedFoodSaved;
  final String? savedFoodErrorMessage;

  bool get isFullSuccess => foodEntrySaved && savedFoodErrorMessage == null;
}
