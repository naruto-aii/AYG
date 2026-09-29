import '../models/food_visibility.dart';
import '../models/saved_food.dart';

/// 公開食品 [SavedFood.version] の更新ルール（Version 1.1）。
class SavedFoodVersionPolicy {
  const SavedFoodVersionPolicy._();

  static const int initialVersion = 1;

  /// 利用者へ影響する項目が変わったか。
  static bool hasUserFacingChanges(SavedFood previous, SavedFood next) {
    return previous.name != next.name ||
        previous.normalizedName != next.normalizedName ||
        previous.baseAmount != next.baseAmount ||
        previous.unitType != next.unitType ||
        previous.servingUnitLabel != next.servingUnitLabel ||
        previous.kcalPerBase != next.kcalPerBase ||
        previous.proteinPerBase != next.proteinPerBase ||
        previous.fatPerBase != next.fatPerBase ||
        previous.carbPerBase != next.carbPerBase;
  }

  /// 公開食品の利用者向け内容変更時に version を +1 する。
  static SavedFood applyVersionOnUpdate({
    required SavedFood previous,
    required SavedFood next,
  }) {
    if (previous.visibility != FoodVisibility.public) {
      return next;
    }
    if (!hasUserFacingChanges(previous, next)) {
      return next;
    }
    return next.copyWith(version: previous.version + 1);
  }

  /// 公開食品編集前の確認 Popup が必要か。
  static bool requiresPublicUpdateConfirmation(
    SavedFood previous,
    SavedFood next,
  ) {
    return previous.visibility == FoodVisibility.public &&
        hasUserFacingChanges(previous, next);
  }
}
