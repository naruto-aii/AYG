import '../../models/food_source_type.dart';
import '../../models/food_visibility.dart';

class SavedFoodDisplayLabels {
  SavedFoodDisplayLabels._();

  static String visibility(FoodVisibility visibility) {
    return switch (visibility) {
      FoodVisibility.private => '非公開',
      FoodVisibility.public => '公開',
      FoodVisibility.unlisted => '限定公開',
    };
  }

  static String sourceType(FoodSourceType sourceType) {
    return switch (sourceType) {
      FoodSourceType.manual => '手入力',
      FoodSourceType.openFoodFacts => 'Open Food Facts',
      FoodSourceType.openFoodFactsDerived => 'OFF派生',
      FoodSourceType.copied => 'コピー',
    };
  }
}
