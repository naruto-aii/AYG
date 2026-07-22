/// kcal / P / F / C の入力フィールド。
enum MacroField { kcal, protein, fat, carb }

/// フィールド値の由来。
enum MacroFieldSource { empty, loaded, user, auto }

/// パース結果。
enum MacroParseState { empty, partial, invalid, valid }

class ParsedMacroInput {
  const ParsedMacroInput({required this.state, this.value});

  const ParsedMacroInput.empty() : state = MacroParseState.empty, value = null;

  final MacroParseState state;
  final double? value;

  bool get isValid => state == MacroParseState.valid;
}
