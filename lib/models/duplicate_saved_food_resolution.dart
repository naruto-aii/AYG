import '../models/duplicate_saved_food_action.dart';
import '../models/saved_food.dart';
import '../models/saved_food_draft.dart';

/// 同名 private 食品保存時の解決内容。
class DuplicateSavedFoodResolution {
  const DuplicateSavedFoodResolution({
    required this.action,
    required this.draft,
    this.existingFood,
    this.newName,
  });

  final DuplicateSavedFoodAction action;
  final SavedFoodDraft draft;
  final SavedFood? existingFood;
  final String? newName;
}
