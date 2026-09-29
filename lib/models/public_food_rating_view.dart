import 'food_rating.dart';

/// 公開食品の評価表示状態。
class PublicFoodRatingView {
  const PublicFoodRatingView({
    required this.goodCount,
    required this.badCount,
    required this.myRating,
    required this.canRate,
  });

  final int goodCount;
  final int badCount;
  final FoodRatingType? myRating;
  final bool canRate;

  bool get hasLowRating => badCount >= 3 && badCount > goodCount * 2;
}

class PublicFoodRatingResult {
  const PublicFoodRatingResult({
    required this.success,
    this.view,
    this.errorMessage,
  });

  final bool success;
  final PublicFoodRatingView? view;
  final String? errorMessage;
}

class PublicFoodReportResult {
  const PublicFoodReportResult({required this.success, this.errorMessage});

  final bool success;
  final String? errorMessage;
}
