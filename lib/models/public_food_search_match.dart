import 'saved_food.dart';

enum PublicFoodSearchMatchType { exactName, prefixName, partialName, barcode }

extension PublicFoodSearchMatchTypeX on PublicFoodSearchMatchType {
  int get rankScore => switch (this) {
    PublicFoodSearchMatchType.exactName => 100,
    PublicFoodSearchMatchType.barcode => 95,
    PublicFoodSearchMatchType.prefixName => 80,
    PublicFoodSearchMatchType.partialName => 40,
  };
}

/// 公開食品検索結果（Good/Bad 件数・一致種別付き）。
class PublicFoodSearchMatch {
  const PublicFoodSearchMatch({
    required this.food,
    required this.goodCount,
    required this.badCount,
    required this.matchType,
  });

  final SavedFood food;
  final int goodCount;
  final int badCount;
  final PublicFoodSearchMatchType matchType;

  bool get hasLowRating => badCount >= 3 && badCount > goodCount * 2;
}
