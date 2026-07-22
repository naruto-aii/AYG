import '../models/food_entry.dart';
import '../models/food_entry_source.dart';
import '../models/food_unit_type.dart';

/// 旧 quantity ベースの FoodEntry を D1 モデルへ移行する。
class FoodEntryLegacyMigration {
  const FoodEntryLegacyMigration._();

  /// 既存行: baseAmount=1, unitType=serving, consumedAmount=旧quantity。
  /// 合計値は multiplier = quantity のまま維持される。
  static FoodEntry fromLegacyQuantity({
    required String id,
    required String name,
    double? kcalPerUnit,
    double? proteinPerUnit,
    double? fatPerUnit,
    double? carbPerUnit,
    required double quantity,
    required DateTime loggedAt,
  }) {
    return FoodEntry(
      id: id,
      name: name,
      kcalPerBase: kcalPerUnit,
      proteinPerBase: proteinPerUnit,
      fatPerBase: fatPerUnit,
      carbPerBase: carbPerUnit,
      baseAmount: 1,
      unitType: FoodUnitType.serving,
      consumedAmount: quantity,
      sourceType: FoodEntrySource.manual,
      loggedAt: loggedAt,
    );
  }

  /// Isar / Supabase から新列なしで読み込んだ場合の補完。
  static FoodEntry applyLegacyDefaults(FoodEntry entry) {
    if (entry.hasConsumptionModel) {
      return entry;
    }
    return entry.copyWith(
      baseAmount: 1,
      unitType: FoodUnitType.serving,
      consumedAmount: entry.legacyQuantityFallback,
    );
  }
}
