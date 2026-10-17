import 'package:ayg/models/food_entry_source.dart';
import 'package:ayg/models/macro_field.dart';
import 'package:ayg/services/macro_nutrition_consistency_policy.dart';
import 'package:ayg/widgets/food/macro_nutrition_input_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MacroNutritionInputController newController() =>
      MacroNutritionInputController();

  void enter(
    MacroNutritionInputController controller,
    MacroField field,
    String value,
  ) {
    controller.controllerFor(field).text = value;
    controller.onFieldChanged(field);
  }

  group('MacroNutritionInputController manual mode', () {
    test('initializeFromNullable does not auto-calculate missing field', () {
      final controller = newController();
      controller.initializeFromNullable(kcal: 200, protein: 10, fat: 5);

      expect(controller.carbController.text, isEmpty);
      expect(controller.sourceOf(MacroField.carb), MacroFieldSource.empty);
      expect(controller.autoField, isNull);
      controller.dispose();
    });

    test('auto-fills kcal from protein fat carb', () {
      final controller = newController();
      enter(controller, MacroField.protein, '10');
      enter(controller, MacroField.fat, '5');
      enter(controller, MacroField.carb, '20');

      expect(controller.kcalController.text, '165');
      expect(controller.sourceOf(MacroField.kcal), MacroFieldSource.auto);
      expect(controller.sourceOf(MacroField.protein), MacroFieldSource.user);
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
      enter(controller, MacroField.kcal, '10');
      enter(controller, MacroField.fat, '50');
      enter(controller, MacroField.carb, '50');

      expect(controller.proteinController.text, isEmpty);
      expect(controller.negativeMessage, isNotNull);
      expect(controller.canSave, isFalse);
      controller.dispose();
    });

    test('negative numbers block save', () {
      final controller = newController();
      enter(controller, MacroField.kcal, '-1');

      expect(controller.canSave, isFalse);
      expect(controller.prepareForSave(), isFalse);
      controller.dispose();
    });

    test('does not auto-fill with only two values', () {
      final controller = newController();
      enter(controller, MacroField.protein, '10');
      enter(controller, MacroField.fat, '5');

      expect(controller.kcalController.text, isEmpty);
      expect(controller.carbController.text, isEmpty);
      controller.dispose();
    });

    test('zero is treated as valid input', () {
      final controller = newController();
      enter(controller, MacroField.kcal, '36');
      enter(controller, MacroField.protein, '0');
      enter(controller, MacroField.fat, '0');

      expect(controller.carbController.text, '9.0');
      expect(controller.sourceOf(MacroField.carb), MacroFieldSource.auto);
      controller.dispose();
    });

    test('auto-calculates protein from kcal fat carb', () {
      final controller = newController();
      enter(controller, MacroField.kcal, '200');
      enter(controller, MacroField.fat, '8');
      enter(controller, MacroField.carb, '20');

      expect(controller.proteinController.text, '12.0');
      expect(controller.sourceOf(MacroField.protein), MacroFieldSource.auto);
      controller.dispose();
    });

    test('auto-calculates fat from kcal protein carb', () {
      final controller = newController();
      enter(controller, MacroField.kcal, '200');
      enter(controller, MacroField.protein, '20');
      enter(controller, MacroField.carb, '20');

      expect(controller.fatController.text, '4.4');
      controller.dispose();
    });

    test('auto-calculates carb from kcal protein fat', () {
      final controller = newController();
      enter(controller, MacroField.kcal, '200');
      enter(controller, MacroField.protein, '20');
      enter(controller, MacroField.fat, '8');

      expect(controller.carbController.text, '12.0');
      controller.dispose();
    });

    test('auto-fills kcal even when empty kcal field was focused', () {
      final controller = newController();
      controller.onFieldFocus(MacroField.kcal);
      enter(controller, MacroField.protein, '10');
      enter(controller, MacroField.fat, '5');
      enter(controller, MacroField.carb, '20');

      expect(controller.kcalController.text, '165');
      controller.dispose();
    });

    test('four user values stay even when kcal is not the formula', () {
      final controller = newController();
      enter(controller, MacroField.kcal, '200');
      enter(controller, MacroField.protein, '10');
      enter(controller, MacroField.fat, '5');
      controller.onFieldFocus(MacroField.carb);
      enter(controller, MacroField.carb, '10');

      expect(controller.kcalController.text, '200');
      expect(controller.proteinController.text, '10');
      expect(controller.fatController.text, '5');
      expect(controller.carbController.text, '10');
      expect(controller.sourceOf(MacroField.kcal), MacroFieldSource.user);
      expect(controller.sourceOf(MacroField.protein), MacroFieldSource.user);
      expect(controller.sourceOf(MacroField.fat), MacroFieldSource.user);
      expect(controller.sourceOf(MacroField.carb), MacroFieldSource.user);
      expect(controller.canSave, isTrue);
      expect(controller.prepareForSave(), isTrue);
      expect(controller.kcalController.text, '200');
      expect(controller.carbController.text, '10');
      controller.dispose();
    });

    test('editing kcal 300 to 450 scales protein fat carb once', () {
      final controller = newController();
      enter(controller, MacroField.kcal, '300');
      enter(controller, MacroField.protein, '20');
      enter(controller, MacroField.fat, '10');
      enter(controller, MacroField.carb, '30');
      enter(controller, MacroField.kcal, '450');

      expect(controller.kcalController.text, '450');
      expect(controller.proteinController.text, '30.0');
      expect(controller.fatController.text, '15.0');
      expect(controller.carbController.text, '45.0');
      expect(controller.sourceOf(MacroField.protein), MacroFieldSource.user);
      expect(controller.sourceOf(MacroField.fat), MacroFieldSource.user);
      expect(controller.sourceOf(MacroField.carb), MacroFieldSource.user);
      controller.dispose();
    });

    test('kcal keystrokes scale against the edit baseline', () {
      final controller = newController();
      enter(controller, MacroField.kcal, '300');
      enter(controller, MacroField.protein, '10');
      enter(controller, MacroField.kcal, '100');
      expect(controller.proteinController.text, '3.3');

      enter(controller, MacroField.kcal, '200');
      expect(controller.proteinController.text, '6.7');
      expect(controller.fatController.text, isEmpty);
      expect(controller.carbController.text, isEmpty);
      controller.dispose();
    });

    test('does not scale protein fat carb when previous kcal is 0', () {
      final controller = newController();
      enter(controller, MacroField.kcal, '0');
      enter(controller, MacroField.protein, '20');
      enter(controller, MacroField.kcal, '100');

      expect(controller.kcalController.text, '100');
      expect(controller.proteinController.text, '20');
      expect(controller.fatController.text, isEmpty);
      controller.dispose();
    });

    test('empty protein fat carb stay empty when kcal changes', () {
      final controller = newController();
      enter(controller, MacroField.kcal, '200');
      enter(controller, MacroField.protein, '10');
      enter(controller, MacroField.kcal, '400');

      expect(controller.proteinController.text, '20.0');
      expect(controller.sourceOf(MacroField.protein), MacroFieldSource.user);
      expect(controller.fatController.text, isEmpty);
      expect(controller.carbController.text, isEmpty);
      controller.dispose();
    });

    test('scaled auto field stays auto and user fields stay user', () {
      final controller = newController();
      enter(controller, MacroField.kcal, '200');
      enter(controller, MacroField.fat, '8');
      enter(controller, MacroField.carb, '20');
      expect(controller.sourceOf(MacroField.protein), MacroFieldSource.auto);

      enter(controller, MacroField.kcal, '400');

      expect(controller.proteinController.text, '24.0');
      expect(controller.sourceOf(MacroField.protein), MacroFieldSource.auto);
      expect(controller.fatController.text, '16.0');
      expect(controller.sourceOf(MacroField.fat), MacroFieldSource.user);
      expect(controller.carbController.text, '40.0');
      expect(controller.sourceOf(MacroField.carb), MacroFieldSource.user);
      controller.dispose();
    });

    test('editing protein adjusts kcal by delta and leaves fat and carb', () {
      final controller = newController();
      enter(controller, MacroField.kcal, '300');
      enter(controller, MacroField.protein, '20');
      enter(controller, MacroField.fat, '10');
      enter(controller, MacroField.carb, '30');
      enter(controller, MacroField.protein, '30');

      expect(controller.kcalController.text, '340');
      expect(controller.proteinController.text, '30');
      expect(controller.fatController.text, '10');
      expect(controller.carbController.text, '30');
      controller.dispose();
    });

    test('protein keystrokes adjust kcal against the edit baseline', () {
      final controller = newController();
      enter(controller, MacroField.kcal, '300');
      enter(controller, MacroField.protein, '20');
      controller.onFieldFocus(MacroField.protein);
      enter(controller, MacroField.protein, '2');
      expect(controller.kcalController.text, '228');

      enter(controller, MacroField.protein, '25');
      expect(controller.kcalController.text, '320');
      expect(controller.fatController.text, isEmpty);
      expect(controller.carbController.text, isEmpty);
      controller.dispose();
    });

    test('clearing a touched auto field does not refill it', () {
      final controller = newController();
      enter(controller, MacroField.kcal, '200');
      enter(controller, MacroField.protein, '20');
      enter(controller, MacroField.fat, '8');
      expect(controller.carbController.text, '12.0');
      expect(controller.sourceOf(MacroField.carb), MacroFieldSource.auto);

      controller.onFieldFocus(MacroField.carb);
      enter(controller, MacroField.carb, '');

      expect(controller.carbController.text, isEmpty);
      expect(controller.sourceOf(MacroField.carb), MacroFieldSource.empty);
      expect(controller.kcalController.text, '200');
      expect(controller.proteinController.text, '20');
      expect(controller.fatController.text, '8');
      controller.dispose();
    });

    test('clearing a user field does not refill it', () {
      final controller = newController();
      enter(controller, MacroField.protein, '10');
      enter(controller, MacroField.fat, '5');
      enter(controller, MacroField.carb, '20');
      expect(controller.kcalController.text, '165');

      controller.onFieldFocus(MacroField.carb);
      enter(controller, MacroField.carb, '');
      expect(controller.carbController.text, isEmpty);
      expect(controller.kcalController.text, '85');
      expect(controller.proteinController.text, '10');
      expect(controller.fatController.text, '5');

      controller.onFieldFocus(MacroField.carb);
      enter(controller, MacroField.carb, '20');
      expect(controller.carbController.text, '20');
      expect(controller.kcalController.text, '85');
      expect(controller.proteinController.text, '10');
      expect(controller.fatController.text, '5');
      controller.dispose();
    });

    test('tapping an auto field keeps the value and makes it user', () {
      final controller = newController();
      enter(controller, MacroField.protein, '10');
      enter(controller, MacroField.fat, '5');
      enter(controller, MacroField.carb, '20');

      controller.onFieldFocus(MacroField.kcal);

      expect(controller.kcalController.text, '165');
      expect(controller.sourceOf(MacroField.kcal), MacroFieldSource.user);
      expect(controller.autoField, isNull);
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

    test('a finished number still composing fills the remaining field', () {
      final controller = newController();
      enter(controller, MacroField.kcal, '200');
      enter(controller, MacroField.protein, '20');
      controller.fatController.value = const TextEditingValue(
        text: '8',
        composing: TextRange(start: 0, end: 1),
      );
      controller.onFieldChanged(MacroField.fat);

      expect(controller.carbController.text, '12.0');
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

    test('editing external value switches to manual and applies rules', () {
      final controller = newController();
      controller.applyExternalValues(
        kcal: 539,
        protein: 6.3,
        fat: 30.9,
        carb: 57.5,
      );

      enter(controller, MacroField.protein, '7.3');

      expect(controller.consistencyMode, MacroNutritionConsistencyMode.manual);
      expect(controller.nutritionEditedByUser, isTrue);
      expect(controller.kcalController.text, '543');
      expect(controller.fatController.text, '30.9');
      expect(controller.carbController.text, '57.5');
      expect(controller.proteinController.text, '7.3');
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
