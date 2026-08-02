import '../constants/app_strings.dart';
import '../models/macro_field.dart';
import 'nutrition_format.dart';

/// ユーザー向けマクロ栄養素ラベル。
String macroFieldLabel(MacroField field) {
  return switch (field) {
    MacroField.kcal => 'kcal',
    MacroField.protein => AppStrings.macroProtein,
    MacroField.fat => AppStrings.macroFat,
    MacroField.carb => AppStrings.macroCarb,
  };
}

/// 1単位あたり入力欄ラベル。
String macroFieldInputLabel(MacroField field) {
  return switch (field) {
    MacroField.kcal => 'kcal（1単位あたり・任意）',
    MacroField.protein => '${AppStrings.macroProtein}（1単位あたり g・任意）',
    MacroField.fat => '${AppStrings.macroFat}（1単位あたり g・任意）',
    MacroField.carb => '${AppStrings.macroCarb}（1単位あたり g・任意）',
  };
}

/// 「タンパク質 23g」形式。
String formatMacroGramsLine(
  String label,
  double? grams, {
  int fractionDigits = 0,
}) {
  return '$label ${formatNullableNutrient(grams, fractionDigits: fractionDigits)}g';
}

/// 改行区切りのマクロサマリー（履歴など）。
String formatMacroSummaryMultiline({
  double? kcal,
  double? proteinG,
  double? fatG,
  double? carbG,
  String? quantityLine,
  int fractionDigits = 0,
}) {
  final lines = <String>[
    if (kcal != null)
      '${formatNullableNutrient(kcal, fractionDigits: fractionDigits)} kcal',
    if (proteinG != null)
      formatMacroGramsLine(
        AppStrings.macroProtein,
        proteinG,
        fractionDigits: fractionDigits,
      ),
    if (fatG != null)
      formatMacroGramsLine(
        AppStrings.macroFat,
        fatG,
        fractionDigits: fractionDigits,
      ),
    if (carbG != null)
      formatMacroGramsLine(
        AppStrings.macroCarb,
        carbG,
        fractionDigits: fractionDigits,
      ),
    if (quantityLine != null) quantityLine,
  ];
  return lines.join('\n');
}

/// 中点区切りの1行サマリー（狭い ListTile subtitle 向け）。
String formatMacroSummaryInline({
  double? kcal,
  double? proteinG,
  double? fatG,
  double? carbG,
  int fractionDigits = 0,
}) {
  final parts = <String>[
    if (kcal != null)
      '${formatNullableNutrient(kcal, fractionDigits: fractionDigits)} kcal',
    if (proteinG != null)
      formatMacroGramsLine(
        AppStrings.macroProtein,
        proteinG,
        fractionDigits: fractionDigits,
      ),
    if (fatG != null)
      formatMacroGramsLine(
        AppStrings.macroFat,
        fatG,
        fractionDigits: fractionDigits,
      ),
    if (carbG != null)
      formatMacroGramsLine(
        AppStrings.macroCarb,
        carbG,
        fractionDigits: fractionDigits,
      ),
  ];
  return parts.join(' · ');
}
