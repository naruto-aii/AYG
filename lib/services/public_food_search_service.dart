import '../models/public_food_search_match.dart';
import '../models/saved_food.dart';
import '../utils/food_name_normalizer.dart';

/// 公開食品検索結果の分類・並べ替え。
class PublicFoodSearchService {
  const PublicFoodSearchService();

  List<PublicFoodSearchMatch> rankResults({
    required List<SavedFood> candidates,
    required String query,
    required Map<String, ({int goodCount, int badCount})> ratingsByKey,
  }) {
    final normalizedQuery = FoodNameNormalizer.normalize(query);
    final trimmedQuery = query.trim();
    if (normalizedQuery.isEmpty && trimmedQuery.isEmpty) {
      return const [];
    }

    final matches = <PublicFoodSearchMatch>[];
    for (final food in candidates) {
      final matchType = _detectBestMatchType(
        food: food,
        normalizedQuery: normalizedQuery,
        trimmedQuery: trimmedQuery,
      );
      if (matchType == null) {
        continue;
      }
      final key = _foodKey(food);
      final rating = ratingsByKey[key];
      matches.add(
        PublicFoodSearchMatch(
          food: food,
          goodCount: rating?.goodCount ?? 0,
          badCount: rating?.badCount ?? 0,
          matchType: matchType,
        ),
      );
    }

    matches.sort((a, b) {
      final scoreA = _totalScore(a);
      final scoreB = _totalScore(b);
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }
      final updatedCompare = b.food.updatedAt.compareTo(a.food.updatedAt);
      if (updatedCompare != 0) {
        return updatedCompare;
      }
      return a.food.normalizedName.compareTo(b.food.normalizedName);
    });

    return matches;
  }

  int _totalScore(PublicFoodSearchMatch match) {
    var score = match.matchType.rankScore;
    if (match.hasLowRating) {
      score -= 20;
    }
    return score;
  }

  PublicFoodSearchMatchType? _detectBestMatchType({
    required SavedFood food,
    required String normalizedQuery,
    required String trimmedQuery,
  }) {
    PublicFoodSearchMatchType? best;

    void consider(PublicFoodSearchMatchType type) {
      if (best == null || type.rankScore > best!.rankScore) {
        best = type;
      }
    }

    if (normalizedQuery.isNotEmpty) {
      if (food.normalizedName == normalizedQuery) {
        consider(PublicFoodSearchMatchType.exactName);
      } else if (food.normalizedName.startsWith(normalizedQuery)) {
        consider(PublicFoodSearchMatchType.prefixName);
      } else if (food.normalizedName.contains(normalizedQuery)) {
        consider(PublicFoodSearchMatchType.partialName);
      }
    }

    final barcode = food.barcode;
    if (barcode != null &&
        barcode.isNotEmpty &&
        trimmedQuery.isNotEmpty &&
        barcode == trimmedQuery) {
      consider(PublicFoodSearchMatchType.barcode);
    }

    return best;
  }

  String _foodKey(SavedFood food) => '${food.ownerUserId}:${food.foodId}';
}
