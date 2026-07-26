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

  group('reconcileField', () {
    test('recalculates kcal from PFC', () {
      final result = NutritionValueCalculator.reconcileField(
        field: MacroField.kcal,
        kcal: v(200),
        protein: v(10),
        fat: v(5),
        carb: v(10),
      );

      expect(result!.value, 125);
      expect(result.negative, isFalse);
    });
  });

  group('isConsistent', () {
    test('matches 4/9/4 formula after rounding', () {
      expect(
        NutritionValueCalculator.isConsistent(
          kcal: 165,
          protein: 10,
          fat: 5,
          carb: 20,
        ),
        isTrue,
      );
    });

    test('rejects inconsistent values', () {
      expect(
        NutritionValueCalculator.isConsistent(
          kcal: 200,
          protein: 10,
          fat: 5,
          carb: 10,
        ),
        isFalse,
      );
    });
  });

  group('normalizeSnapshot', () {
    test('uses PFC as truth and recalculates kcal', () {
      final normalized = NutritionValueCalculator.normalizeSnapshot(
        kcal: 539,
        protein: 6.3,
        fat: 30.9,
        carb: 57.5,
      );

      expect(normalized.kcal, 533);
      expect(normalized.protein, 6.3);
      expect(normalized.fat, 30.9);
      expect(normalized.carb, 57.5);
      expect(normalized.referenceKcal, 539);
    });

    test('keeps partial values when PFC incomplete', () {
      final normalized = NutritionValueCalculator.normalizeSnapshot(
        kcal: 100,
        protein: null,
        fat: null,
        carb: null,
      );

      expect(normalized.kcal, 100);
      expect(normalized.referenceKcal, isNull);
    });
  });
}
