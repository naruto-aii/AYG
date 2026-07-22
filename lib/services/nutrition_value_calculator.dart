import '../models/macro_field.dart';

/// kcal / P / F / C の相互計算と整合性チェック（純粋関数）。
class NutritionValueCalculator {
  const NutritionValueCalculator();

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

    final p = protein.value ?? 0;
    final f = fat.value ?? 0;
    final c = carb.value ?? 0;
    final k = kcal.value ?? 0;

    final double raw;
    switch (missing) {
      case MacroField.kcal:
        raw = p * 4 + f * 9 + c * 4;
      case MacroField.protein:
        raw = (k - f * 9 - c * 4) / 4;
      case MacroField.fat:
        raw = (k - p * 4 - c * 4) / 9;
      case MacroField.carb:
        raw = (k - p * 4 - f * 9) / 4;
    }

    if (raw < 0) {
      return MacroCalculationResult(field: missing, negative: true);
    }

    return MacroCalculationResult(
      field: missing,
      value: _round(missing, raw),
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

  /// 4 項目すべて valid のとき、許容差超過を返す。
  static MacroConsistencyWarning? checkConsistency({
    required double kcal,
    required double protein,
    required double fat,
    required double carb,
  }) {
    final derived = derivedKcal(protein: protein, fat: fat, carb: carb);
    final tolerance = _tolerance(kcal);
    final diff = (kcal - derived).abs();
    if (diff <= tolerance) {
      return null;
    }
    return MacroConsistencyWarning(
      inputKcal: kcal,
      derivedKcal: _round(MacroField.kcal, derived),
      differenceKcal: diff,
      toleranceKcal: tolerance,
    );
  }

  static double _tolerance(double inputKcal) {
    final percent = inputKcal.abs() * 0.02;
    return percent > 5 ? percent : 5;
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

class MacroConsistencyWarning {
  const MacroConsistencyWarning({
    required this.inputKcal,
    required this.derivedKcal,
    required this.differenceKcal,
    required this.toleranceKcal,
  });

  final double inputKcal;
  final double derivedKcal;
  final double differenceKcal;
  final double toleranceKcal;
}
