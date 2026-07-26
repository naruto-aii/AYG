import '../models/food_entry_source.dart';

/// kcal / P / F / C の整合ルールモード。
enum MacroNutritionConsistencyMode {
  /// 手入力: kcal = P×4 + F×9 + C×4 を強制。
  manual,

  /// 外部取得値: OFF 等の表示値をそのまま保持（不一致許容）。
  preserveExternal,
}

/// [FoodEntrySource] に応じた栄養値整合ポリシー。
class MacroNutritionConsistencyPolicy {
  const MacroNutritionConsistencyPolicy._();

  static MacroNutritionConsistencyMode initialModeFor(FoodEntrySource source) {
    return switch (source) {
      FoodEntrySource.manual => MacroNutritionConsistencyMode.manual,
      FoodEntrySource.openFoodFacts =>
        MacroNutritionConsistencyMode.preserveExternal,
      FoodEntrySource.savedFood =>
        MacroNutritionConsistencyMode.preserveExternal,
      FoodEntrySource.template =>
        MacroNutritionConsistencyMode.preserveExternal,
    };
  }

  /// 保存時の sourceType。栄養値を編集した場合は manual へ切り替える。
  static FoodEntrySource resolveSaveSourceType({
    required FoodEntrySource initialSourceType,
    required bool nutritionEditedByUser,
  }) {
    if (!nutritionEditedByUser) {
      return initialSourceType;
    }

    return switch (initialSourceType) {
      FoodEntrySource.manual => FoodEntrySource.manual,
      FoodEntrySource.openFoodFacts => FoodEntrySource.manual,
      FoodEntrySource.savedFood => FoodEntrySource.manual,
      FoodEntrySource.template => FoodEntrySource.manual,
    };
  }

  static bool enforceManualConsistency(MacroNutritionConsistencyMode mode) {
    return mode == MacroNutritionConsistencyMode.manual;
  }
}
