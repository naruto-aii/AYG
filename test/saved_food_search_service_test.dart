import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/models/food_status.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/services/saved_food_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = SavedFoodSearchService();
  final now = DateTime(2026, 7, 20);

  SavedFood food({
    required String id,
    required String name,
    required String normalizedName,
    int useCount = 0,
    DateTime? lastUsedAt,
    DateTime? updatedAt,
  }) {
    return SavedFood(
      foodId: id,
      ownerUserId: 'user-a',
      name: name,
      normalizedName: normalizedName,
      baseAmount: 100,
      unitType: FoodUnitType.g,
      sourceType: FoodSourceType.manual,
      status: FoodStatus.active,
      useCount: useCount,
      lastUsedAt: lastUsedAt,
      createdAt: now,
      updatedAt: updatedAt ?? now,
    );
  }

  group('SavedFoodSearchService', () {
    test('prioritizes exact match over prefix match', () {
      final results = service.rankOwnResults(
        foods: [
          food(id: '1', name: 'りんご酢', normalizedName: 'りんご酢'),
          food(id: '2', name: 'りんご', normalizedName: 'りんご'),
        ],
        query: 'りんご',
      );

      expect(results.first.foodId, '2');
    });

    test('supports Japanese prefix search', () {
      final results = service.rankOwnResults(
        foods: [
          food(id: '1', name: '鶏むね肉', normalizedName: '鶏むね肉'),
          food(id: '2', name: '鮭', normalizedName: '鮭'),
        ],
        query: '鶏',
      );

      expect(results, hasLength(1));
      expect(results.first.name, '鶏むね肉');
    });

    test('sorts by use count and last used when query is empty', () {
      final results = service.rankOwnResults(
        foods: [
          food(
            id: '1',
            name: 'A',
            normalizedName: 'a',
            useCount: 1,
            updatedAt: now,
          ),
          food(
            id: '2',
            name: 'B',
            normalizedName: 'b',
            useCount: 5,
            lastUsedAt: now.add(const Duration(days: 1)),
            updatedAt: now,
          ),
        ],
        query: '',
      );

      expect(results.first.foodId, '2');
    });
  });
}
