import '../constants/official_food_copy.dart';
import '../models/food_source_type.dart';
import '../models/saved_food.dart';

/// 成分表由来のマイ食品へ出典を付ける。公開後も外さない。
class OfficialFoodProvenance {
  const OfficialFoodProvenance._();

  static SavedFood attach(SavedFood food) {
    if (food.sourceType != FoodSourceType.mextSfct) {
      return food;
    }
    return food.copyWith(sourceAttribution: OfficialFoodCopy.fullAttribution);
  }
}
