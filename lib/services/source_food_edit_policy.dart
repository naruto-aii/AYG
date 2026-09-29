import '../models/food_entry.dart';
import '../models/food_unit_type.dart';

/// 履歴編集時の登録元保存食品更新選択。
enum SourceFoodUpdateChoice {
  entryOnly,
  updateSource,
  copyAndUpdateSource,
  cancel,
}

/// 履歴編集時に登録元保存食品へ影響する変更かを判定。
class SourceFoodEditPolicy {
  const SourceFoodEditPolicy._();

  static bool hasLinkedSource(FoodEntry? entry) {
    return entry?.savedFoodId != null;
  }

  /// 数量・日時のみの変更（登録元ダイアログ不要）。
  static bool isConsumptionOnlyChange({
    required FoodEntry original,
    required FoodEntry updated,
  }) {
    return _sameSourceFields(original, updated) &&
        (original.consumedAmount != updated.consumedAmount ||
            original.loggedAt != updated.loggedAt);
  }

  /// 1単位当たり成分・商品情報に相当する変更。
  static bool affectsSourceFood({
    required FoodEntry original,
    required FoodEntry updated,
  }) {
    if (original.savedFoodId == null) {
      return false;
    }
    return !_sameSourceFields(original, updated);
  }

  static bool _sameSourceFields(FoodEntry a, FoodEntry b) {
    return a.name == b.name &&
        a.kcalPerBase == b.kcalPerBase &&
        a.proteinPerBase == b.proteinPerBase &&
        a.fatPerBase == b.fatPerBase &&
        a.carbPerBase == b.carbPerBase &&
        a.baseAmount == b.baseAmount &&
        a.unitType == b.unitType;
  }

  static SavedFoodPatch fromFoodEntry(FoodEntry entry) {
    return SavedFoodPatch(
      name: entry.name,
      baseAmount: entry.baseAmount,
      unitType: entry.unitType,
      kcalPerBase: entry.kcalPerBase,
      proteinPerBase: entry.proteinPerBase,
      fatPerBase: entry.fatPerBase,
      carbPerBase: entry.carbPerBase,
    );
  }
}

class SavedFoodPatch {
  const SavedFoodPatch({
    required this.name,
    required this.baseAmount,
    required this.unitType,
    this.kcalPerBase,
    this.proteinPerBase,
    this.fatPerBase,
    this.carbPerBase,
  });

  final String name;
  final double baseAmount;
  final FoodUnitType unitType;
  final double? kcalPerBase;
  final double? proteinPerBase;
  final double? fatPerBase;
  final double? carbPerBase;
}
