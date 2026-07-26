import '../models/food_status.dart';
import '../models/food_visibility.dart';
import '../models/saved_food.dart';
import '../utils/food_name_normalizer.dart';

/// 同名 private 保存済み食品の検出。
class SavedFoodDuplicateService {
  const SavedFoodDuplicateService();

  SavedFood? findPrivateDuplicateByName({
    required List<SavedFood> ownFoods,
    required String name,
    String? excludeFoodId,
  }) {
    final normalized = FoodNameNormalizer.normalize(name);
    for (final food in ownFoods) {
      if (excludeFoodId != null && food.foodId == excludeFoodId) {
        continue;
      }
      if (food.status != FoodStatus.active || food.deletedAt != null) {
        continue;
      }
      if (food.visibility != FoodVisibility.private) {
        continue;
      }
      if (food.normalizedName == normalized) {
        return food;
      }
    }
    return null;
  }
}
