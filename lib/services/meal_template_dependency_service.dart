import '../models/food_status.dart';
import '../models/food_visibility.dart';
import '../models/meal_template.dart';
import '../models/meal_template_apply.dart';
import '../models/saved_food.dart';

typedef SavedFoodLookup =
    Future<SavedFood?> Function({
      required String ownerUserId,
      required String foodId,
      required bool isOwn,
    });

typedef CreatorBlockedLookup = Future<bool> Function(String creatorUserId);

/// テンプレート利用前の依存関係チェック。
class MealTemplateDependencyService {
  const MealTemplateDependencyService();

  Future<List<MealTemplateDependencyIssue>> analyze({
    required List<MealTemplateItem> items,
    required SavedFoodLookup lookupFood,
    required CreatorBlockedLookup isCreatorBlocked,
  }) async {
    final issues = <MealTemplateDependencyIssue>[];
    for (final item in items) {
      final savedFoodId = item.savedFoodId;
      final sourceOwnerUserId = item.sourceOwnerUserId;
      if (savedFoodId == null || sourceOwnerUserId == null) {
        continue;
      }

      if (await isCreatorBlocked(sourceOwnerUserId)) {
        issues.add(
          MealTemplateDependencyIssue(
            item: item,
            kind: MealTemplateDependencyKind.creatorBlocked,
          ),
        );
        continue;
      }

      final isOwn = false; // resolved by lookup callback
      final food = await lookupFood(
        ownerUserId: sourceOwnerUserId,
        foodId: savedFoodId,
        isOwn: isOwn,
      );

      if (food == null || food.deletedAt != null) {
        issues.add(
          MealTemplateDependencyIssue(
            item: item,
            kind: MealTemplateDependencyKind.sourceDeleted,
          ),
        );
        continue;
      }

      if (!_isFoodUsable(food)) {
        issues.add(
          MealTemplateDependencyIssue(
            item: item,
            kind: MealTemplateDependencyKind.sourceHidden,
            currentFood: food,
          ),
        );
        continue;
      }

      if (_hasUserFacingChange(item: item, food: food)) {
        issues.add(
          MealTemplateDependencyIssue(
            item: item,
            kind: MealTemplateDependencyKind.sourceChanged,
            currentFood: food,
          ),
        );
      }
    }
    return issues;
  }

  bool _isFoodUsable(SavedFood food) {
    if (food.visibility == FoodVisibility.public) {
      return food.isPublicActive;
    }
    return food.status == FoodStatus.active && food.deletedAt == null;
  }

  bool _hasUserFacingChange({
    required MealTemplateItem item,
    required SavedFood food,
  }) {
    return item.name != food.name ||
        item.baseAmount != food.baseAmount ||
        item.unitType != food.unitType ||
        item.kcalPerBase != food.kcalPerBase ||
        item.proteinPerBase != food.proteinPerBase ||
        item.fatPerBase != food.fatPerBase ||
        item.carbPerBase != food.carbPerBase;
  }
}
