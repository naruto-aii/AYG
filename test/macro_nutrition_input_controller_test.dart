import 'package:ayg/models/macro_field.dart';
import 'package:ayg/widgets/food/macro_nutrition_input_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MacroNutritionInputController newController() =>
      MacroNutritionInputController();

  group('MacroNutritionInputController', () {
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
      controller.dispose();
    });

    test('does not overwrite when all four fields are valid', () {
      final controller = newController();
      controller.kcalController.text = '200';
      controller.proteinController.text = '10';
      controller.fatController.text = '5';
      controller.carbController.text = '10';
      controller.onFieldChanged(MacroField.carb);

      expect(controller.kcalController.text, '200');
      expect(controller.proteinController.text, '10');
      expect(controller.consistencyWarning, isNotNull);
      controller.dispose();
    });

    test('does not overwrite locked auto field after manual edit', () {
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

    test('parseOptional returns null for empty field', () {
      final controller = newController();
      expect(controller.parseOptional(MacroField.kcal), isNull);
      controller.dispose();
    });
  });
}
