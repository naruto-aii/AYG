import 'package:ayg/constants/official_food_copy.dart';
import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/repositories/supabase/supabase_saved_food_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('buildPrivateCopy always records the source owner', () {
    final repo = SupabaseSavedFoodRepository(
      client: SupabaseClient('http://127.0.0.1:54321', 'test-key'),
    );
    final now = DateTime.utc(2026, 9, 28);
    final source = SavedFood(
      foodId: 'src-food',
      ownerUserId: '11111111-1111-1111-1111-111111111111',
      name: 'ご飯',
      normalizedName: 'ご飯',
      baseAmount: 100,
      unitType: FoodUnitType.g,
      visibility: FoodVisibility.public,
      sourceType: FoodSourceType.mextSfct,
      officialFoodCode: '01088',
      officialFoodName: 'こめ',
      sourceAttribution: OfficialFoodCopy.storedAttribution,
      createdAt: now,
      updatedAt: now,
    );

    final copy = repo.buildPrivateCopy(
      source: source,
      newFoodId: 'copy-food',
      ownerUserId: '33333333-3333-3333-3333-333333333333',
      now: now,
    );

    expect(copy.copiedFromFoodId, 'src-food');
    expect(copy.copiedFromOwnerUserId, source.ownerUserId);
    expect(copy.copiedFromOwnerUserId, isNotNull);
    expect(copy.ownerUserId, '33333333-3333-3333-3333-333333333333');
  });
}
