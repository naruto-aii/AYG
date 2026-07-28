import 'package:ayg/models/public_food_publish_match.dart';
import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/models/food_status.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/repositories/exceptions/food_master_exceptions.dart';
import 'package:ayg/services/public_food_similar_service.dart';
import 'package:ayg/services/publish_error_messages.dart';
import 'package:ayg/services/saved_food_publish_validator.dart';
import 'package:flutter_test/flutter_test.dart';

SavedFood sampleFood({
  String id = 'food-1',
  String name = 'テスト',
  FoodVisibility visibility = FoodVisibility.private,
  double baseAmount = 100,
  FoodUnitType unitType = FoodUnitType.g,
  String? servingUnitLabel = 'g',
  double? kcal = 165,
  double? protein = 10,
  double? fat = 5,
  double? carb = 20,
  FoodSourceType sourceType = FoodSourceType.manual,
  String? barcode,
}) {
  return SavedFood(
    foodId: id,
    ownerUserId: 'user-a',
    name: name,
    normalizedName: name.toLowerCase(),
    baseAmount: baseAmount,
    unitType: unitType,
    servingUnitLabel: servingUnitLabel,
    visibility: visibility,
    status: FoodStatus.active,
    kcalPerBase: kcal,
    proteinPerBase: protein,
    fatPerBase: fat,
    carbPerBase: carb,
    sourceType: sourceType,
    barcode: barcode,
    createdAt: DateTime(2026, 7, 20),
    updatedAt: DateTime(2026, 7, 20),
  );
}

void main() {
  group('SavedFoodPublishValidator', () {
    const validator = SavedFoodPublishValidator();

    test('accepts valid private manual food', () {
      final result = validator.validate(
        food: sampleFood(),
        ownerUserId: 'user-a',
      );
      expect(result.isValid, isTrue);
      expect(result.manualMacroConsistent, isTrue);
    });

    test('rejects missing macros', () {
      final result = validator.validate(
        food: sampleFood(kcal: null),
        ownerUserId: 'user-a',
      );
      expect(result.isValid, isFalse);
    });

    test('rejects inconsistent manual macros', () {
      final result = validator.validate(
        food: sampleFood(kcal: 999),
        ownerUserId: 'user-a',
      );
      expect(result.isValid, isFalse);
      expect(result.manualMacroConsistent, isFalse);
    });
  });

  group('PublicFoodSimilarService', () {
    const service = PublicFoodSimilarService();

    test('detects same name different amount', () {
      final matches = service.classify(
        candidate: sampleFood(id: 'b', name: 'キャベツ', baseAmount: 200),
        source: sampleFood(name: 'キャベツ', baseAmount: 100),
        goodCount: 1,
        badCount: 0,
      );
      expect(matches, hasLength(1));
      expect(matches.first.reason.label, contains('基準量'));
    });

    test('ignores exact duplicate', () {
      final food = sampleFood(name: 'rice');
      final matches = service.classify(
        candidate: food,
        source: food,
        goodCount: 0,
        badCount: 0,
      );
      expect(matches, isEmpty);
    });
  });

  group('PublishErrorMessages', () {
    test('maps duplicate to user message', () {
      expect(
        PublishErrorMessages.messageForKind(PublishFailureKind.duplicate),
        contains('同じ食品名'),
      );
    });

    test('maps rate limits', () {
      expect(
        PublishErrorMessages.messageForKind(PublishFailureKind.rateLimitHourly),
        contains('1時間'),
      );
      expect(
        PublishErrorMessages.messageForKind(PublishFailureKind.rateLimitDaily),
        contains('本日'),
      );
    });
  });
}
