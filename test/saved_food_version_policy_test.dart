import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/services/saved_food_version_policy.dart';
import 'package:flutter_test/flutter_test.dart';

SavedFood _publicFood({int version = 1, String name = 'Rice'}) {
  return SavedFood(
    foodId: 'f1',
    ownerUserId: 'u1',
    name: name,
    normalizedName: name.toLowerCase(),
    baseAmount: 100,
    unitType: FoodUnitType.g,
    visibility: FoodVisibility.public,
    kcalPerBase: 120,
    version: version,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('SavedFoodVersionPolicy', () {
    test('initial version is 1', () {
      expect(SavedFoodVersionPolicy.initialVersion, 1);
      expect(_publicFood().version, 1);
    });

    test('detects user-facing changes', () {
      final previous = _publicFood();
      final next = previous.copyWith(kcalPerBase: 130);

      expect(
        SavedFoodVersionPolicy.hasUserFacingChanges(previous, next),
        isTrue,
      );
      expect(
        SavedFoodVersionPolicy.requiresPublicUpdateConfirmation(previous, next),
        isTrue,
      );
    });

    test('ignores non user-facing changes', () {
      final previous = _publicFood();
      final next = previous.copyWith(useCount: 5, barcode: '123');

      expect(
        SavedFoodVersionPolicy.hasUserFacingChanges(previous, next),
        isFalse,
      );
    });

    test('bumps version for public food user-facing update', () {
      final previous = _publicFood(version: 2);
      final next = previous.copyWith(
        name: 'Brown Rice',
        normalizedName: 'brown rice',
      );

      final result = SavedFoodVersionPolicy.applyVersionOnUpdate(
        previous: previous,
        next: next,
      );

      expect(result.version, 3);
    });

    test('does not bump version for private food', () {
      final previous = _publicFood().copyWith(
        visibility: FoodVisibility.private,
      );
      final next = previous.copyWith(kcalPerBase: 200);

      final result = SavedFoodVersionPolicy.applyVersionOnUpdate(
        previous: previous,
        next: next,
      );

      expect(result.version, 1);
    });
  });
}
