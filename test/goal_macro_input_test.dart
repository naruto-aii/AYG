import 'package:ayg/models/macro_field.dart';
import 'package:ayg/services/goal_macro_input.dart';
import 'package:ayg/widgets/nutrition/calorie_target_editor.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  GoalMacroInput edit({
    required GoalMacroInput input,
    required MacroField field,
    required TextEditingController kcal,
    required TextEditingController protein,
    required TextEditingController fat,
    required TextEditingController carb,
  }) {
    input.onUserEdit(
      edited: field,
      kcal: kcal,
      protein: protein,
      fat: fat,
      carb: carb,
    );
    return input;
  }

  test('two PFC values and kcal fill the remaining carb', () {
    final input = GoalMacroInput();
    final kcal = TextEditingController(text: '2000');
    final protein = TextEditingController(text: '130');
    final fat = TextEditingController(text: '55');
    final carb = TextEditingController();

    edit(
      input: input,
      field: MacroField.kcal,
      kcal: kcal,
      protein: protein,
      fat: fat,
      carb: carb,
    );
    edit(
      input: input,
      field: MacroField.protein,
      kcal: kcal,
      protein: protein,
      fat: fat,
      carb: carb,
    );
    edit(
      input: input,
      field: MacroField.fat,
      kcal: kcal,
      protein: protein,
      fat: fat,
      carb: carb,
    );

    expect(carb.text, '246.3');
    expect(input.autoField, MacroField.carb);
    expect(input.message, isNull);
    expect(
      goalMacroSaveMessage(
        kcalText: kcal.text,
        proteinText: protein.text,
        fatText: fat.text,
        carbText: carb.text,
      ),
      isNull,
    );
    expect(
      validateManualCalorieTargets(
        kcalText: kcal.text,
        proteinText: protein.text,
        fatText: fat.text,
        carbText: carb.text,
      ),
      isNull,
    );

    kcal.dispose();
    protein.dispose();
    fat.dispose();
    carb.dispose();
  });

  test('negative remainder is shown and blocks save', () {
    final input = GoalMacroInput();
    final kcal = TextEditingController(text: '500');
    final protein = TextEditingController(text: '30');
    final fat = TextEditingController(text: '500');
    final carb = TextEditingController();

    edit(
      input: input,
      field: MacroField.fat,
      kcal: kcal,
      protein: protein,
      fat: fat,
      carb: carb,
    );

    expect(carb.text, isEmpty);
    expect(input.message, 'この組み合わせでは炭水化物がマイナスになります。');
    expect(
      validateManualCalorieTargets(
        kcalText: '500',
        proteinText: '30',
        fatText: '500',
        carbText: '',
      ),
      'この組み合わせでは炭水化物がマイナスになります。',
    );

    kcal.dispose();
    protein.dispose();
    fat.dispose();
    carb.dispose();
  });

  test('typed kcal and PFC that do not add up cannot be saved', () {
    final input = GoalMacroInput();
    final kcal = TextEditingController(text: '500');
    final protein = TextEditingController(text: '30');
    final fat = TextEditingController(text: '500');
    final carb = TextEditingController();

    edit(
      input: input,
      field: MacroField.kcal,
      kcal: kcal,
      protein: protein,
      fat: fat,
      carb: carb,
    );
    edit(
      input: input,
      field: MacroField.protein,
      kcal: kcal,
      protein: protein,
      fat: fat,
      carb: carb,
    );
    edit(
      input: input,
      field: MacroField.fat,
      kcal: kcal,
      protein: protein,
      fat: fat,
      carb: carb,
    );
    carb.text = '20000';
    edit(
      input: input,
      field: MacroField.carb,
      kcal: kcal,
      protein: protein,
      fat: fat,
      carb: carb,
    );

    expect(carb.text, '20000');
    expect(protein.text, '30');
    expect(input.message, GoalMacroInput.inconsistentMessage);
    expect(
      validateManualCalorieTargets(
        kcalText: kcal.text,
        proteinText: protein.text,
        fatText: fat.text,
        carbText: carb.text,
      ),
      GoalMacroInput.inconsistentMessage,
    );

    kcal.dispose();
    protein.dispose();
    fat.dispose();
    carb.dispose();
  });

  test('prefilled values recompute an untouched field on the first edit', () {
    final input = GoalMacroInput();
    final kcal = TextEditingController(text: '2000');
    final protein = TextEditingController(text: '130');
    final fat = TextEditingController(text: '55');
    final carb = TextEditingController(text: '220');

    edit(
      input: input,
      field: MacroField.kcal,
      kcal: kcal,
      protein: protein,
      fat: fat,
      carb: carb,
    );

    expect(carb.text, '246.3');
    expect(input.message, isNull);

    kcal.dispose();
    protein.dispose();
    fat.dispose();
    carb.dispose();
  });
}
