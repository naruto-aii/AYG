enum FoodRatingType { good, bad }

extension FoodRatingTypeX on FoodRatingType {
  String get storageValue => name;

  static FoodRatingType? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    return switch (raw) {
      'good' => FoodRatingType.good,
      'bad' => FoodRatingType.bad,
      _ => null,
    };
  }
}

class FoodRatingSummary {
  const FoodRatingSummary({
    required this.foodOwnerUserId,
    required this.foodId,
    required this.goodCount,
    required this.badCount,
    required this.updatedAt,
  });

  final String foodOwnerUserId;
  final String foodId;
  final int goodCount;
  final int badCount;
  final DateTime updatedAt;
}

class MyFoodRating {
  const MyFoodRating({
    required this.ratingId,
    required this.foodOwnerUserId,
    required this.foodId,
    required this.ratingType,
    required this.updatedAt,
  });

  final String ratingId;
  final String foodOwnerUserId;
  final String foodId;
  final FoodRatingType ratingType;
  final DateTime updatedAt;
}
