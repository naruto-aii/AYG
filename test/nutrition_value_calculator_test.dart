import 'package:ayg/models/macro_field.dart';
import 'package:ayg/services/nutrition_value_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ParsedMacroInput v(double n) =>
      ParsedMacroInput(state: MacroParseState.valid, value: n);

  group('parse', () {
    test('empty vs zero', () {
      expect(NutritionValueCalculator.parse('').state, MacroParseState.empty);
      expect(NutritionValueCalculator.parse('0').value, 0);
    });

    test('partial decimal', () {
      expect(
        NutritionValueCalculator.parse('12.').state,
        MacroParseState.partial,
      );
    });

    test('negative is invalid', () {
      expect(
        NutritionValueCalculator.parse('-1').state,
        MacroParseState.invalid,
      );
    });
  });

  group('calculateMissing', () {
    test('kcal missing', () {
      final result = NutritionValueCalculator.calculateMissing(
        kcal: const ParsedMacroInput.empty(),
        protein: v(10),
        fat: v(5),
        carb: v(20),
      );
      expect(result!.field, MacroField.kcal);
      expect(result.value, 165);
    });

    test('protein missing', () {
      final result = NutritionValueCalculator.calculateMissing(
        kcal: v(165),
        protein: const ParsedMacroInput.empty(),
        fat: v(5),
        carb: v(20),
      );
      expect(result!.field, MacroField.protein);
      expect(result.value, 10);
    });

    test('fat missing', () {
      final result = NutritionValueCalculator.calculateMissing(
        kcal: v(165),
        protein: v(10),
        fat: const ParsedMacroInput.empty(),
        carb: v(20),
      );
      expect(result!.field, MacroField.fat);
      expect(result.value, 5);
    });

    test('carb missing', () {
      final result = NutritionValueCalculator.calculateMissing(
        kcal: v(165),
        protein: v(10),
        fat: v(5),
        carb: const ParsedMacroInput.empty(),
      );
      expect(result!.field, MacroField.carb);
      expect(result.value, 20);
    });

    test('two or fewer valid fields returns null', () {
      expect(
        NutritionValueCalculator.calculateMissing(
          kcal: v(100),
          protein: v(10),
          fat: const ParsedMacroInput.empty(),
          carb: const ParsedMacroInput.empty(),
        ),
        isNull,
      );
    });

    test('negative result', () {
      final result = NutritionValueCalculator.calculateMissing(
        kcal: v(10),
        protein: const ParsedMacroInput.empty(),
        fat: v(50),
        carb: v(50),
      );
      expect(result!.negative, isTrue);
    });

    test('rounds macros to one decimal', () {
      final result = NutritionValueCalculator.calculateMissing(
        kcal: v(100),
        protein: const ParsedMacroInput.empty(),
        fat: v(3),
        carb: v(10),
      );
      expect(result!.value, 8.3);
    });

    test('rounds kcal to integer', () {
      final result = NutritionValueCalculator.calculateMissing(
        kcal: const ParsedMacroInput.empty(),
        protein: v(10),
        fat: v(5),
        carb: v(19.875),
      );
      expect(result!.field, MacroField.kcal);
      expect(result.value, 165);
    });
  });

  group('checkConsistency', () {
    test('within tolerance returns null', () {
      expect(
        NutritionValueCalculator.checkConsistency(
          kcal: 165,
          protein: 10,
          fat: 5,
          carb: 20,
        ),
        isNull,
      );
    });

    test('exceeds max of 5 kcal or 2 percent', () {
      final warning = NutritionValueCalculator.checkConsistency(
        kcal: 200,
        protein: 10,
        fat: 5,
        carb: 10,
      );
      expect(warning, isNotNull);
      expect(warning!.differenceKcal, greaterThan(5));
    });

    test('uses 2 percent for large kcal', () {
      final warning = NutritionValueCalculator.checkConsistency(
        kcal: 1000,
        protein: 10,
        fat: 5,
        carb: 10,
      );
      expect(warning!.toleranceKcal, 20);
    });
  });
}
