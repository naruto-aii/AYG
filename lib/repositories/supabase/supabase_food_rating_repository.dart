import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/food_rating.dart';
import '../contracts/food_rating_repository_base.dart';
import 'food_master_row_mapper.dart';
import 'supabase_error_mapper.dart';

class SupabaseFoodRatingRepository implements FoodRatingRepositoryBase {
  SupabaseFoodRatingRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<void> setGood({
    required String foodOwnerUserId,
    required String foodId,
    required String raterUserId,
    required String ratingId,
  }) => _upsertRating(
    ratingId: ratingId,
    foodOwnerUserId: foodOwnerUserId,
    foodId: foodId,
    raterUserId: raterUserId,
    ratingType: FoodRatingType.good,
  );

  @override
  Future<void> setBad({
    required String foodOwnerUserId,
    required String foodId,
    required String raterUserId,
    required String ratingId,
  }) => _upsertRating(
    ratingId: ratingId,
    foodOwnerUserId: foodOwnerUserId,
    foodId: foodId,
    raterUserId: raterUserId,
    ratingType: FoodRatingType.bad,
  );

  Future<void> _upsertRating({
    required String ratingId,
    required String foodOwnerUserId,
    required String foodId,
    required String raterUserId,
    required FoodRatingType ratingType,
  }) async {
    try {
      await _client.from('food_ratings').upsert({
        'rating_id': ratingId,
        'food_owner_user_id': foodOwnerUserId,
        'food_id': foodId,
        'rater_user_id': raterUserId,
        'rating_type': ratingType.storageValue,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'rater_user_id,food_owner_user_id,food_id');
    } catch (error) {
      throw SupabaseErrorMapper.map(error, context: 'food_ratings upsert');
    }
  }

  @override
  Future<void> clearRating({
    required String foodOwnerUserId,
    required String foodId,
    required String raterUserId,
  }) async {
    try {
      await _client
          .from('food_ratings')
          .delete()
          .eq('food_owner_user_id', foodOwnerUserId)
          .eq('food_id', foodId)
          .eq('rater_user_id', raterUserId);
    } catch (error) {
      throw SupabaseErrorMapper.map(error, context: 'food_ratings delete');
    }
  }

  @override
  Future<FoodRatingSummary?> getSummary({
    required String foodOwnerUserId,
    required String foodId,
  }) async {
    try {
      final row = await _client
          .from('food_rating_stats')
          .select()
          .eq('food_owner_user_id', foodOwnerUserId)
          .eq('food_id', foodId)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      return FoodMasterRowMapper.ratingSummaryFromRow(row);
    } catch (error) {
      throw SupabaseErrorMapper.map(error, context: 'food_rating_stats get');
    }
  }

  @override
  Future<MyFoodRating?> getMyRating({
    required String foodOwnerUserId,
    required String foodId,
    required String raterUserId,
  }) async {
    try {
      final row = await _client
          .from('food_ratings')
          .select()
          .eq('food_owner_user_id', foodOwnerUserId)
          .eq('food_id', foodId)
          .eq('rater_user_id', raterUserId)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      return FoodMasterRowMapper.myRatingFromRow(row);
    } catch (error) {
      throw SupabaseErrorMapper.map(error, context: 'food_ratings get mine');
    }
  }
}
