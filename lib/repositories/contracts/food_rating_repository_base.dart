import '../../models/food_rating.dart';

abstract class FoodRatingRepositoryBase {
  Future<void> setGood({
    required String foodOwnerUserId,
    required String foodId,
    required String raterUserId,
    required String ratingId,
  });

  Future<void> setBad({
    required String foodOwnerUserId,
    required String foodId,
    required String raterUserId,
    required String ratingId,
  });

  Future<void> clearRating({
    required String foodOwnerUserId,
    required String foodId,
    required String raterUserId,
  });

  Future<FoodRatingSummary?> getSummary({
    required String foodOwnerUserId,
    required String foodId,
  });

  Future<MyFoodRating?> getMyRating({
    required String foodOwnerUserId,
    required String foodId,
    required String raterUserId,
  });
}
