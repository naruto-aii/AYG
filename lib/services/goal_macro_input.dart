import 'package:flutter/widgets.dart';

import '../models/macro_field.dart';
import 'nutrition_value_calculator.dart';

/// 目標設定の手入力。カロリーと PFC の 3 項目から残り 1 項目を出す。
class GoalMacroInput {
  static const _solveOrder = <MacroField>[
    MacroField.carb,
    MacroField.fat,
    MacroField.protein,
    MacroField.kcal,
  ];

  MacroField? autoField;
  String? message;
  final Set<MacroField> touched = {};

  /// プログラムが書き換えた欄。呼び出し側はその欄だけを再描画する。
  MacroField? onUserEdit({
    required MacroField edited,
    required TextEditingController kcal,
    required TextEditingController protein,
    required TextEditingController fat,
    required TextEditingController carb,
  }) {
    final editedAutoField = autoField == edited;
    if (editedAutoField) {
      autoField = null;
    }
    touched.add(edited);

    final controllers = _controllers(
      kcal: kcal,
      protein: protein,
      fat: fat,
      carb: carb,
    );
    final parsed = NutritionValueCalculator.parse(controllers[edited]!.text);
    if (parsed.state == MacroParseState.partial ||
        parsed.state == MacroParseState.invalid) {
      message = parsed.state == MacroParseState.invalid ? '数字で入力してください。' : null;
      return null;
    }

    message = null;
    final values = _read(controllers);
    final empty = [
      for (final field in MacroField.values)
        if (values[field]!.state == MacroParseState.empty) field,
    ];
    final validCount = values.values.where((value) => value.isValid).length;

    if (validCount <= 2) {
      return _clearAuto(controllers);
    }

    if (validCount == 3 && empty.length == 1) {
      return _fill(empty.single, controllers, values);
    }

    if (validCount == 4) {
      if (!editedAutoField && autoField != null && autoField != edited) {
        return _fill(autoField!, controllers, values);
      }
      if (!editedAutoField && autoField == null) {
        final untouched = _solveOrder.where(
          (field) => field != edited && !touched.contains(field),
        );
        if (untouched.isNotEmpty) {
          return _fill(untouched.first, controllers, values);
        }
      }
      if (!GoalMacroInput.isConsistent(values)) {
        message = inconsistentMessage;
      }
    }
    return null;
  }

  void reset() {
    autoField = null;
    message = null;
    touched.clear();
  }

  static const inconsistentMessage =
      'カロリーとPFCが合いません。たんぱく質×4 + 脂質×9 + 炭水化物×4 がカロリーになる必要があります。';

  static const remainderMismatchMessage = 'この組み合わせは 4・9・4 の換算で合いません。';

  static String negativeMessage(MacroField field) {
    return 'この組み合わせでは${_label(field)}がマイナスになります。';
  }

  static bool isConsistent(Map<MacroField, ParsedMacroInput> values) {
    if (values.values.any((value) => !value.isValid)) {
      return false;
    }
    return NutritionValueCalculator.isConsistent(
      kcal: values[MacroField.kcal]!.value!,
      protein: values[MacroField.protein]!.value!,
      fat: values[MacroField.fat]!.value!,
      carb: values[MacroField.carb]!.value!,
    );
  }

  MacroField? _fill(
    MacroField target,
    Map<MacroField, TextEditingController> controllers,
    Map<MacroField, ParsedMacroInput> values,
  ) {
    final result = NutritionValueCalculator.calculateMissing(
      kcal: _asInput(values, MacroField.kcal, target),
      protein: _asInput(values, MacroField.protein, target),
      fat: _asInput(values, MacroField.fat, target),
      carb: _asInput(values, MacroField.carb, target),
      targetField: target,
    );
    if (result == null) {
      return null;
    }
    if (result.negative || result.value == null) {
      message = negativeMessage(target);
      return _blank(target, controllers);
    }

    final next = Map<MacroField, ParsedMacroInput>.from(values);
    next[target] = ParsedMacroInput(
      state: MacroParseState.valid,
      value: result.value,
    );
    if (!isConsistent(next)) {
      message = remainderMismatchMessage;
      return _blank(target, controllers);
    }

    final formatted = NutritionValueCalculator.formatForField(
      target,
      result.value!,
    );
    final changed = controllers[target]!.text != formatted;
    controllers[target]!.text = formatted;
    autoField = target;
    message = _rangeMessage(target, result.value!);
    return changed ? target : null;
  }

  MacroField? _blank(
    MacroField target,
    Map<MacroField, TextEditingController> controllers,
  ) {
    final hadText = controllers[target]!.text.isNotEmpty;
    controllers[target]!.text = '';
    if (autoField == target) {
      autoField = null;
    }
    return hadText ? target : null;
  }

  ParsedMacroInput _asInput(
    Map<MacroField, ParsedMacroInput> values,
    MacroField field,
    MacroField target,
  ) {
    if (field == target) {
      return const ParsedMacroInput.empty();
    }
    return values[field]!;
  }

  MacroField? _clearAuto(Map<MacroField, TextEditingController> controllers) {
    final field = autoField;
    if (field == null) {
      return null;
    }
    return _blank(field, controllers);
  }

  Map<MacroField, TextEditingController> _controllers({
    required TextEditingController kcal,
    required TextEditingController protein,
    required TextEditingController fat,
    required TextEditingController carb,
  }) {
    return {
      MacroField.kcal: kcal,
      MacroField.protein: protein,
      MacroField.fat: fat,
      MacroField.carb: carb,
    };
  }

  Map<MacroField, ParsedMacroInput> _read(
    Map<MacroField, TextEditingController> controllers,
  ) {
    return {
      for (final field in MacroField.values)
        field: NutritionValueCalculator.parse(controllers[field]!.text),
    };
  }

  static String _label(MacroField field) {
    return switch (field) {
      MacroField.kcal => 'カロリー',
      MacroField.protein => 'たんぱく質',
      MacroField.fat => '脂質',
      MacroField.carb => '炭水化物',
    };
  }

  static String? _rangeMessage(MacroField field, double value) {
    final (min, max, unit) = switch (field) {
      MacroField.kcal => (500.0, 10000.0, 'kcal'),
      MacroField.protein => (0.0, 500.0, 'g/日'),
      MacroField.fat => (0.0, 500.0, 'g/日'),
      MacroField.carb => (0.0, 1500.0, 'g/日'),
    };
    if (value < min || value > max) {
      return '${_label(field)}が ${min.toStringAsFixed(0)}〜${max.toStringAsFixed(0)} $unit に収まりません。';
    }
    return null;
  }
}

/// 保存前の確認。欄の即時計算と同じ理由を返す。
String? goalMacroSaveMessage({
  required String kcalText,
  required String proteinText,
  required String fatText,
  required String carbText,
}) {
  final values = {
    MacroField.kcal: NutritionValueCalculator.parse(kcalText),
    MacroField.protein: NutritionValueCalculator.parse(proteinText),
    MacroField.fat: NutritionValueCalculator.parse(fatText),
    MacroField.carb: NutritionValueCalculator.parse(carbText),
  };
  if (values.values.any(
    (value) =>
        value.state == MacroParseState.partial ||
        value.state == MacroParseState.invalid,
  )) {
    return '数字で入力してください。';
  }
  final validCount = values.values.where((value) => value.isValid).length;
  if (validCount < 4) {
    if (validCount == 3) {
      final missing = values.entries
          .firstWhere((entry) => !entry.value.isValid)
          .key;
      final result = NutritionValueCalculator.calculateMissing(
        kcal: values[MacroField.kcal]!,
        protein: values[MacroField.protein]!,
        fat: values[MacroField.fat]!,
        carb: values[MacroField.carb]!,
        targetField: missing,
      );
      if (result == null || result.negative || result.value == null) {
        return GoalMacroInput.negativeMessage(missing);
      }
      final next = Map<MacroField, ParsedMacroInput>.from(values);
      next[missing] = ParsedMacroInput(
        state: MacroParseState.valid,
        value: result.value,
      );
      if (!GoalMacroInput.isConsistent(next)) {
        return GoalMacroInput.remainderMismatchMessage;
      }
    }
    return null;
  }
  if (!GoalMacroInput.isConsistent(values)) {
    return GoalMacroInput.inconsistentMessage;
  }
  return null;
}
