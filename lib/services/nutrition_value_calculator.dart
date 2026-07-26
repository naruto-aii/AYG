import '../models/macro_field.dart';

/// kcal / P / F / C の相互計算と整合性チェック（純粋関数）。
class NutritionValueCalculator {
  const NutritionValueCalculator();

  static const double _consistencyEpsilon = 0.001;

  static ParsedMacroInput parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const ParsedMacroInput.empty();
    }
    if (trimmed == '-' || trimmed.endsWith('.') || trimmed == '-.') {
      return const ParsedMacroInput(state: MacroParseState.partial);
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      return const ParsedMacroInput(state: MacroParseState.invalid);
    }
    if (parsed < 0) {
      return const ParsedMacroInput(state: MacroParseState.invalid);
    }
    return ParsedMacroInput(state: MacroParseState.valid, value: parsed);
  }

  /// 3 項目が valid のとき、欠損 1 項目を計算する。
  static MacroCalculationResult? calculateMissing({
    required ParsedMacroInput kcal,
    required ParsedMacroInput protein,
    required ParsedMacroInput fat,
    required ParsedMacroInput carb,
    MacroField? targetField,
  }) {
    final fields = <MacroField, ParsedMacroInput>{
      MacroField.kcal: kcal,
      MacroField.protein: protein,
      MacroField.fat: fat,
      MacroField.carb: carb,
    };

    final validCount = fields.values.where((f) => f.isValid).length;
    if (validCount != 3) {
      return null;
    }

    MacroField? missing;
    for (final entry in fields.entries) {
      if (!entry.value.isValid) {
        if (entry.value.state == MacroParseState.partial ||
            entry.value.state == MacroParseState.invalid) {
          return null;
        }
        missing = entry.key;
      }
    }
    if (missing == null) {
      return null;
    }

    final field = targetField ?? missing;
    if (!fields[field]!.isValid && field != missing) {
      return null;
    }

    return _calculateField(
      field: field,
      kcal: kcal.value ?? 0,
      protein: protein.value ?? 0,
      fat: fat.value ?? 0,
      carb: carb.value ?? 0,
    );
  }

  /// 指定フィールドを他 3 項目から再計算する。
  static MacroCalculationResult? reconcileField({
    required MacroField field,
    required ParsedMacroInput kcal,
    required ParsedMacroInput protein,
    required ParsedMacroInput fat,
    required ParsedMacroInput carb,
  }) {
    final fields = <MacroField, ParsedMacroInput>{
      MacroField.kcal: kcal,
      MacroField.protein: protein,
      MacroField.fat: fat,
      MacroField.carb: carb,
    };

    if (!fields.values.every((value) => value.isValid)) {
      return null;
    }

    return _calculateField(
      field: field,
      kcal: kcal.value!,
      protein: protein.value!,
      fat: fat.value!,
      carb: carb.value!,
    );
  }

  static MacroCalculationResult _calculateField({
    required MacroField field,
    required double kcal,
    required double protein,
    required double fat,
    required double carb,
  }) {
    final double raw;
    switch (field) {
      case MacroField.kcal:
        raw = protein * 4 + fat * 9 + carb * 4;
      case MacroField.protein:
        raw = (kcal - fat * 9 - carb * 4) / 4;
      case MacroField.fat:
        raw = (kcal - protein * 4 - carb * 4) / 9;
      case MacroField.carb:
        raw = (kcal - protein * 4 - fat * 9) / 4;
    }

    if (raw < 0) {
      return MacroCalculationResult(field: field, negative: true);
    }

    return MacroCalculationResult(
      field: field,
      value: _round(field, raw),
      negative: false,
    );
  }

  static double _round(MacroField field, double value) {
    switch (field) {
      case MacroField.kcal:
        return value.roundToDouble();
      case MacroField.protein:
      case MacroField.fat:
      case MacroField.carb:
        return (value * 10).roundToDouble() / 10;
    }
  }

  static double derivedKcal({
    required double protein,
    required double fat,
    required double carb,
  }) {
    return protein * 4 + fat * 9 + carb * 4;
  }

  /// 4 項目すべて valid のとき、4/9/4 換算式と一致するか。
  static bool isConsistent({
    required double kcal,
    required double protein,
    required double fat,
    required double carb,
  }) {
    final derived = _round(
      MacroField.kcal,
      derivedKcal(protein: protein, fat: fat, carb: carb),
    );
    final roundedKcal = _round(MacroField.kcal, kcal);
    return (roundedKcal - derived).abs() < _consistencyEpsilon;
  }

  /// 4 項目すべて valid のとき、PFC 換算 kcal と表示 kcal が不一致か。
  static bool hasExternalCalorieMismatch({
    required double kcal,
    required double protein,
    required double fat,
    required double carb,
  }) {
    return !isConsistent(kcal: kcal, protein: protein, fat: fat, carb: carb);
  }

  static String formatForField(MacroField field, double value) {
    switch (field) {
      case MacroField.kcal:
        return value.round().toString();
      case MacroField.protein:
      case MacroField.fat:
      case MacroField.carb:
        return value.toStringAsFixed(1);
    }
  }
}

class MacroCalculationResult {
  const MacroCalculationResult({
    required this.field,
    this.value,
    required this.negative,
  });

  final MacroField field;
  final double? value;
  final bool negative;
}
