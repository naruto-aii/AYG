import 'package:ayg/services/alcohol_nutrition_calculator.dart';
import 'package:ayg/utils/alcohol_unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlcoholNutritionCalculator', () {
    test('500ml 5% yields 20g pure alcohol', () {
      expect(
        AlcoholNutritionCalculator.calculatePureAlcoholGramsFromMl(
          amountMl: 500,
          alcoholPercentage: 5,
        ),
        20,
      );
    });

    test('20g pure alcohol yields 140 kcal', () {
      expect(AlcoholNutritionCalculator.calculateAlcoholCalories(20), 140);
    });

    test('350ml 5% yields 14g pure alcohol', () {
      expect(
        AlcoholNutritionCalculator.calculatePureAlcoholGramsFromMl(
          amountMl: 350,
          alcoholPercentage: 5,
        ),
        14,
      );
    });

    test('decimal alcohol percentage is supported', () {
      expect(
        AlcoholNutritionCalculator.calculatePureAlcoholGramsFromMl(
          amountMl: 100,
          alcoholPercentage: 4.5,
        ),
        closeTo(3.6, 0.001),
      );
    });

    test('uses alcohol_calories as total when total_calories omitted', () {
      final result = AlcoholNutritionCalculator.resolve(
        amount: 500,
        unit: 'ml',
        alcoholPercentage: 5,
      );
      expect(result.alcoholCalories, 140);
      expect(result.totalCalories, 140);
      expect(result.totalCaloriesIsEstimated, isTrue);
    });

    test('uses provided total_calories without double counting alcohol', () {
      final result = AlcoholNutritionCalculator.resolve(
        amount: 500,
        unit: 'ml',
        alcoholPercentage: 5,
        totalCaloriesInput: 200,
      );
      expect(result.alcoholCalories, 140);
      expect(result.totalCalories, 200);
      expect(result.totalCaloriesIsEstimated, isFalse);
    });

    test('recalculates alcohol_calories from manual pure_alcohol_grams', () {
      final result = AlcoholNutritionCalculator.resolve(
        amount: 2,
        unit: '缶',
        alcoholPercentage: 5,
        manualPureAlcoholGrams: 18,
      );
      expect(result.pureAlcoholGrams, 18);
      expect(result.alcoholCalories, 126);
      expect(result.totalCalories, 126);
      expect(result.totalCaloriesIsEstimated, isTrue);
      expect(result.canAutoCalculatePureAlcohol, isFalse);
    });
  });

  group('isMilliliterUnit', () {
    test('normalizes ml variants', () {
      expect(isMilliliterUnit('ml'), isTrue);
      expect(isMilliliterUnit('mL'), isTrue);
      expect(isMilliliterUnit('ＭＬ'), isTrue);
      expect(isMilliliterUnit('  ミリリットル '), isTrue);
    });

    test('does not treat non-ml units as ml', () {
      expect(isMilliliterUnit('缶'), isFalse);
      expect(isMilliliterUnit('杯'), isFalse);
    });
  });
}
