import 'package:ayg/models/food_status.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/models/public_food_search_match.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/services/public_food_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = PublicFoodSearchService();
  final now = DateTime(2026, 7, 20, 12);

  SavedFood food({
    required String id,
    required String name,
    String? barcode,
    DateTime? updatedAt,
  }) {
    return SavedFood(
      foodId: id,
      ownerUserId: 'owner-$id',
      name: name,
      normalizedName: name,
      baseAmount: 100,
      unitType: FoodUnitType.g,
      kcalPerBase: 200,
      visibility: FoodVisibility.public,
      status: FoodStatus.active,
      barcode: barcode,
      createdAt: now,
      updatedAt: updatedAt ?? now,
    );
  }

  group('PublicFoodSearchService', () {
    test('exact match ranks before prefix and partial', () {
      final exact = food(id: '1', name: 'りんご');
      final prefix = food(id: '2', name: 'りんごジュース');
      final partial = food(id: '3', name: '青りんご');

      final results = service.rankResults(
        candidates: [partial, prefix, exact],
        query: 'りんご',
        ratingsByKey: const {},
      );

      expect(results.map((item) => item.food.foodId).toList(), ['1', '2', '3']);
      expect(results.first.matchType, PublicFoodSearchMatchType.exactName);
    });

    test('barcode exact match is included', () {
      final byBarcode = food(id: 'b1', name: '商品A', barcode: '4901234567890');
      final results = service.rankResults(
        candidates: [byBarcode],
        query: '4901234567890',
        ratingsByKey: const {},
      );

      expect(results, hasLength(1));
      expect(results.first.matchType, PublicFoodSearchMatchType.barcode);
    });

    test('low rating demotes search rank', () {
      final goodFood = food(
        id: 'good',
        name: 'テスト',
        updatedAt: now.add(const Duration(hours: 1)),
      );
      final badFood = food(id: 'bad', name: 'テスト');

      final results = service.rankResults(
        candidates: [badFood, goodFood],
        query: 'テスト',
        ratingsByKey: {
          'owner-bad:bad': (goodCount: 0, badCount: 4),
          'owner-good:good': (goodCount: 2, badCount: 0),
        },
      );

      expect(results.first.food.foodId, 'good');
      expect(results.last.hasLowRating, isTrue);
    });

    test('updatedAt breaks ties', () {
      final older = food(id: 'old', name: 'テスト', updatedAt: now);
      final newer = food(
        id: 'new',
        name: 'テスト',
        updatedAt: now.add(const Duration(days: 1)),
      );

      final results = service.rankResults(
        candidates: [older, newer],
        query: 'テスト',
        ratingsByKey: const {},
      );

      expect(results.first.food.foodId, 'new');
    });
  });
}
