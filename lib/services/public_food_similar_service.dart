import '../models/public_food_publish_match.dart';
import '../models/saved_food.dart';
import '../utils/food_name_normalizer.dart';

/// 公開食品の類似候補判定（Repository 取得結果を分類）。
class PublicFoodSimilarService {
  const PublicFoodSimilarService();

  List<PublicFoodSimilarMatch> classify({
    required SavedFood candidate,
    required SavedFood source,
    required int goodCount,
    required int badCount,
  }) {
    if (_isExactDuplicate(candidate: candidate, source: source)) {
      return const [];
    }
    if (candidate.foodId == source.foodId &&
        candidate.ownerUserId == source.ownerUserId) {
      return const [];
    }

    final reasons = <PublicFoodSimilarReason>{};
    if (candidate.normalizedName == source.normalizedName &&
        (candidate.baseAmount != source.baseAmount ||
            candidate.unitType != source.unitType)) {
      reasons.add(PublicFoodSimilarReason.sameNameDifferentAmount);
    }
    if (candidate.normalizedName.startsWith(source.normalizedName) ||
        source.normalizedName.startsWith(candidate.normalizedName)) {
      if (candidate.normalizedName != source.normalizedName ||
          candidate.baseAmount != source.baseAmount ||
          candidate.unitType != source.unitType) {
        reasons.add(PublicFoodSimilarReason.namePrefix);
      }
    }
    final barcode = source.barcode;
    if (barcode != null && barcode.isNotEmpty && candidate.barcode == barcode) {
      reasons.add(PublicFoodSimilarReason.barcodeMatch);
    }

    if (reasons.isEmpty) {
      return const [];
    }

    return [
      PublicFoodSimilarMatch(
        food: candidate,
        goodCount: goodCount,
        badCount: badCount,
        reason: reasons.first,
      ),
    ];
  }

  List<PublicFoodSimilarMatch> mergeMatches(
    List<PublicFoodSimilarMatch> matches,
  ) {
    final byKey = <String, PublicFoodSimilarMatch>{};
    for (final match in matches) {
      final key = '${match.food.ownerUserId}:${match.food.foodId}';
      byKey.putIfAbsent(key, () => match);
    }
    return byKey.values.toList();
  }

  bool _isExactDuplicate({
    required SavedFood candidate,
    required SavedFood source,
  }) {
    return candidate.normalizedName == source.normalizedName &&
        candidate.baseAmount == source.baseAmount &&
        candidate.unitType == source.unitType;
  }

  bool isExactDuplicatePublic({
    required SavedFood candidate,
    required SavedFood source,
  }) {
    return _isExactDuplicate(candidate: candidate, source: source);
  }
}
