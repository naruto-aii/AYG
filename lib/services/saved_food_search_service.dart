import '../models/saved_food.dart';
import '../utils/food_name_normalizer.dart';

/// 自分の保存済み食品検索結果の並べ替え。
class SavedFoodSearchService {
  const SavedFoodSearchService();

  List<SavedFood> rankOwnResults({
    required List<SavedFood> foods,
    required String query,
  }) {
    final normalizedQuery = FoodNameNormalizer.normalize(query);
    final filtered = foods.where((food) {
      if (normalizedQuery.isEmpty) {
        return true;
      }
      return food.normalizedName.contains(normalizedQuery);
    }).toList();

    filtered.sort((a, b) {
      final scoreA = _score(food: a, normalizedQuery: normalizedQuery);
      final scoreB = _score(food: b, normalizedQuery: normalizedQuery);
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }
      final useCompare = b.useCount.compareTo(a.useCount);
      if (useCompare != 0) {
        return useCompare;
      }
      final lastUsedA = a.lastUsedAt ?? a.updatedAt;
      final lastUsedB = b.lastUsedAt ?? b.updatedAt;
      final usedCompare = lastUsedB.compareTo(lastUsedA);
      if (usedCompare != 0) {
        return usedCompare;
      }
      return a.normalizedName.compareTo(b.normalizedName);
    });

    return filtered;
  }

  int _score({required SavedFood food, required String normalizedQuery}) {
    if (normalizedQuery.isEmpty) {
      return 0;
    }
    if (food.normalizedName == normalizedQuery) {
      return 100;
    }
    if (food.normalizedName.startsWith(normalizedQuery)) {
      return 80;
    }
    return 40;
  }
}
