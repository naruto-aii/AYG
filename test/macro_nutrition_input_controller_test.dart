import 'package:ayg/models/macro_field.dart';
import 'package:ayg/models/food_entry_source.dart';
import 'package:ayg/services/macro_nutrition_consistency_policy.dart';
import 'package:ayg/widgets/food/macro_nutrition_input_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MacroNutritionInputController newController() =>
      MacroNutritionInputController();

  group('MacroNutritionInputController manual mode', () {
    test('initializeFromNullable does not auto-calculate missing field', () {
      final controller = newController();
      controller.initializeFromNullable(kcal: 200, protein: 10, fat: 5);

      expect(controller.carbController.text, isEmpty);
      expect(controller.sourceOf(MacroField.carb), MacroFieldSource.empty);
      controller.dispose();
    });

    test('auto-fills missing field when three values are valid', () {
      final controller = newController();
      controller.kcalController.text = '';
      controller.proteinController.text = '10';
      controller.fatController.text = '5';
      controller.carbController.text = '20';
      controller.onFieldChanged(MacroField.carb);

      expect(controller.kcalController.text, '165');
      expect(controller.sourceOf(MacroField.kcal), MacroFieldSource.auto);
      controller.dispose();
    });

    test('does not calculate with partial decimal input', () {
      final controller = newController();
      controller.proteinController.text = '10';
      controller.fatController.text = '5';
      controller.carbController.text = '12.';
      controller.onFieldChanged(MacroField.carb);

      expect(controller.kcalController.text, isEmpty);
      controller.dispose();
    });

    test('does not auto-fill when result would be negative', () {
      final controller = newController();
      controller.kcalController.text = '10';
      controller.fatController.text = '50';
      controller.carbController.text = '50';
      controller.onFieldChanged(MacroField.carb);

      expect(controller.proteinController.text, isEmpty);
      expect(controller.negativeMessage, isNotNull);
      expect(controller.canSave, isFalse);
      controller.dispose();
    });

    test('reconciles oldest manual field when all four fields are valid', () {
      final controller = newController();
      controller.kcalController.text = '200';
      controller.onFieldChanged(MacroField.kcal);
      controller.proteinController.text = '10';
      controller.onFieldChanged(MacroField.protein);
      controller.fatController.text = '5';
      controller.onFieldChanged(MacroField.fat);
      controller.carbController.text = '10';
      controller.onFieldChanged(MacroField.carb);

      expect(controller.kcalController.text, '125');
      expect(controller.sourceOf(MacroField.kcal), MacroFieldSource.auto);
      expect(controller.canSave, isTrue);
      controller.dispose();
    });

    test('keeps manually edited auto field and recalculates another field', () {
      final controller = newController();
      controller.proteinController.text = '10';
      controller.fatController.text = '5';
      controller.carbController.text = '20';
      controller.onFieldChanged(MacroField.carb);
      expect(controller.kcalController.text, '165');

      controller.onFieldChanged(MacroField.kcal);
      controller.kcalController.text = '170';
      controller.onFieldChanged(MacroField.kcal);

      controller.proteinController.text = '12';
      controller.onFieldChanged(MacroField.protein);

      expect(controller.kcalController.text, '170');
      expect(controller.sourceOf(MacroField.kcal), MacroFieldSource.user);
      controller.dispose();
    });

    test('prepareForSave enforces consistency', () {
      final controller = newController();
      controller.kcalController.text = '200';
      controller.onFieldChanged(MacroField.kcal);
      controller.proteinController.text = '10';
      controller.onFieldChanged(MacroField.protein);
      controller.fatController.text = '5';
      controller.onFieldChanged(MacroField.fat);
      controller.carbController.text = '10';
      controller.onFieldChanged(MacroField.carb);

      expect(controller.prepareForSave(), isTrue);
      expect(controller.kcalController.text, '125');
      controller.dispose();
    });

    test('setImeComposing delays calculation until composition ends', () {
      final controller = newController();
      controller.setImeComposing(true);
      controller.proteinController.text = '10';
      controller.fatController.text = '5';
      controller.carbController.text = '20';
      controller.onFieldChanged(MacroField.carb);

      expect(controller.kcalController.text, isEmpty);

      controller.setImeComposing(false);
      expect(controller.kcalController.text, '165');
      controller.dispose();
    });

    test(
      'composing range on one keystroke does not block later calculations',
      () {
        final controller = newController();
        controller.proteinController.value = const TextEditingValue(
          text: '1',
          composing: TextRange(start: 0, end: 1),
        );
        controller.onFieldChanged(MacroField.protein);

        controller.proteinController.text = '10';
        controller.fatController.text = '5';
        controller.carbController.text = '20';
        controller.onFieldChanged(MacroField.carb);

        expect(controller.kcalController.text, '165');
        controller.dispose();
      },
    );

    test('auto-fills kcal even when empty kcal field was focused', () {
      final controller = newController();
      controller.onFieldFocus(MacroField.kcal);
      controller.proteinController.text = '10';
      controller.onFieldChanged(MacroField.protein);
      controller.fatController.text = '5';
      controller.onFieldChanged(MacroField.fat);
      controller.carbController.text = '20';
      controller.onFieldChanged(MacroField.carb);

      expect(controller.kcalController.text, '165');
      controller.dispose();
    });

    test('auto-calculates protein from kcal fat carb', () {
      final controller = newController();
      controller.kcalController.text = '200';
      controller.onFieldChanged(MacroField.kcal);
      controller.fatController.text = '8';
      controller.onFieldChanged(MacroField.fat);
      controller.carbController.text = '20';
      controller.onFieldChanged(MacroField.carb);

      expect(controller.proteinController.text, '12.0');
      expect(controller.sourceOf(MacroField.protein), MacroFieldSource.auto);
      controller.dispose();
    });

    test('auto-calculates fat from kcal protein carb', () {
      final controller = newController();
      controller.kcalController.text = '200';
      controller.onFieldChanged(MacroField.kcal);
      controller.proteinController.text = '20';
      controller.onFieldChanged(MacroField.protein);
      controller.carbController.text = '20';
      controller.onFieldChanged(MacroField.carb);

      expect(controller.fatController.text, '4.4');
      controller.dispose();
    });

    test('auto-calculates carb from kcal protein fat', () {
      final controller = newController();
      controller.kcalController.text = '200';
      controller.onFieldChanged(MacroField.kcal);
      controller.proteinController.text = '20';
      controller.onFieldChanged(MacroField.protein);
      controller.fatController.text = '8';
      controller.onFieldChanged(MacroField.fat);

      expect(controller.carbController.text, '12.0');
      controller.dispose();
    });

    test('does not auto-fill with only two values', () {
      final controller = newController();
      controller.proteinController.text = '10';
      controller.onFieldChanged(MacroField.protein);
      controller.fatController.text = '5';
      controller.onFieldChanged(MacroField.fat);

      expect(controller.kcalController.text, isEmpty);
      controller.dispose();
    });

    test('zero is treated as valid input', () {
      final controller = newController();
      controller.kcalController.text = '36';
      controller.onFieldChanged(MacroField.kcal);
      controller.proteinController.text = '0';
      controller.onFieldChanged(MacroField.protein);
      controller.fatController.text = '0';
      controller.onFieldChanged(MacroField.fat);

      expect(controller.carbController.text, '9.0');
      controller.dispose();
    });

    test('clearing manual field removes stale auto value', () {
      final controller = newController();
      controller.proteinController.text = '10';
      controller.onFieldChanged(MacroField.protein);
      controller.fatController.text = '5';
      controller.onFieldChanged(MacroField.fat);
      controller.carbController.text = '20';
      controller.onFieldChanged(MacroField.carb);
      expect(controller.kcalController.text, '165');

      controller.carbController.text = '';
      controller.onFieldChanged(MacroField.carb);
      expect(controller.kcalController.text, isEmpty);

      controller.carbController.text = '20';
      controller.onFieldChanged(MacroField.carb);
      expect(controller.kcalController.text, '165');
      controller.dispose();
    });

    test('parseOptional returns null for empty field', () {
      final controller = newController();
      expect(controller.parseOptional(MacroField.kcal), isNull);
      controller.dispose();
    });
  });

  group('MacroNutritionInputController external mode', () {
    test('applyExternalValues preserves OFF kcal without recalculation', () {
      final controller = newController();
      controller.applyExternalValues(
        kcal: 539,
        protein: 6.3,
        fat: 30.9,
        carb: 57.5,
      );

      expect(controller.kcalController.text, '539');
      expect(controller.sourceOf(MacroField.kcal), MacroFieldSource.external);
      expect(
        controller.consistencyMode,
        MacroNutritionConsistencyMode.preserveExternal,
      );
      expect(controller.canSave, isTrue);
      expect(controller.showExternalMismatchNotice, isTrue);
      controller.dispose();
    });

    test('external mode allows save despite mismatch', () {
      final controller = newController();
      controller.applyExternalValues(
        kcal: 539,
        protein: 6.3,
        fat: 30.9,
        carb: 57.5,
      );

      expect(controller.prepareForSave(), isTrue);
      expect(controller.kcalController.text, '539');
      controller.dispose();
    });

    test('editing external value switches to manual mode', () {
      final controller = newController();
      controller.applyExternalValues(
        kcal: 539,
        protein: 6.3,
        fat: 30.9,
        carb: 57.5,
      );

      controller.kcalController.text = '540';
      controller.onFieldChanged(MacroField.kcal);

      expect(controller.consistencyMode, MacroNutritionConsistencyMode.manual);
      expect(controller.nutritionEditedByUser, isTrue);
      controller.dispose();
    });

    test('copied entry loads without auto calculation', () {
      final controller = newController();
      controller.initializeFromNullable(
        kcal: 539,
        protein: 6.3,
        fat: 30.9,
        carb: 57.5,
        consistencyMode: MacroNutritionConsistencyPolicy.initialModeFor(
          FoodEntrySource.savedFood,
        ),
      );

      expect(controller.kcalController.text, '539');
      expect(controller.autoField, isNull);
      expect(controller.canSave, isTrue);
      controller.dispose();
    });
  });
}
