import 'food_entry_source.dart';
import 'food_unit_type.dart';

/// 食事履歴エントリ（記録時点のスナップショット）。
class FoodEntry {
  FoodEntry({
    required this.id,
    required this.name,
    double? kcalPerBase,
    double? proteinPerBase,
    double? fatPerBase,
    double? carbPerBase,
    double? kcalPerUnit,
    double? proteinPerUnit,
    double? fatPerUnit,
    double? carbPerUnit,
    this.baseAmount = 1,
    this.unitType = FoodUnitType.serving,
    double? consumedAmount,
    double? quantity,
    this.sourceType = FoodEntrySource.manual,
    this.savedFoodId,
    this.sourceFoodOwnerUserId,
    this.mealGroupId,
    this.mealGroupName,
    this.sortOrder,
    required this.loggedAt,
  }) : kcalPerBase = kcalPerBase ?? kcalPerUnit,
       proteinPerBase = proteinPerBase ?? proteinPerUnit,
       fatPerBase = fatPerBase ?? fatPerUnit,
       carbPerBase = carbPerBase ?? carbPerUnit,
       consumedAmount = consumedAmount ?? quantity ?? 1,
       assert(baseAmount > 0, 'baseAmount must be positive'),
       assert(
         (consumedAmount ?? quantity ?? 1) > 0,
         'consumedAmount must be positive',
       );

  final String id;
  final String name;

  final double? kcalPerBase;
  final double? proteinPerBase;
  final double? fatPerBase;
  final double? carbPerBase;

  final double baseAmount;
  final FoodUnitType unitType;
  final double consumedAmount;

  final FoodEntrySource sourceType;
  final String? savedFoodId;
  final String? sourceFoodOwnerUserId;

  final String? mealGroupId;
  final String? mealGroupName;
  final int? sortOrder;

  final DateTime loggedAt;

  /// 旧 quantity 互換: multiplier = consumedAmount / baseAmount。
  double get quantity => multiplier;

  /// 旧 per-unit 互換。
  double? get kcalPerUnit => kcalPerBase;
  double? get proteinPerUnit => proteinPerBase;
  double? get fatPerUnit => fatPerBase;
  double? get carbPerUnit => carbPerBase;

  double get multiplier => consumedAmount / baseAmount;

  bool get hasConsumptionModel => baseAmount > 0 && consumedAmount > 0;

  /// Isar 等から quantity のみ読み込んだ場合の fallback。
  double get legacyQuantityFallback => consumedAmount;

  double get totalKcal => (kcalPerBase ?? 0) * multiplier;
  double get totalProteinG => (proteinPerBase ?? 0) * multiplier;
  double get totalFatG => (fatPerBase ?? 0) * multiplier;
  double get totalCarbG => (carbPerBase ?? 0) * multiplier;

  FoodEntry copyWith({
    String? id,
    String? name,
    double? kcalPerBase,
    double? proteinPerBase,
    double? fatPerBase,
    double? carbPerBase,
    double? baseAmount,
    FoodUnitType? unitType,
    double? consumedAmount,
    FoodEntrySource? sourceType,
    String? savedFoodId,
    String? sourceFoodOwnerUserId,
    String? mealGroupId,
    String? mealGroupName,
    int? sortOrder,
    DateTime? loggedAt,
  }) {
    return FoodEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      kcalPerBase: kcalPerBase ?? this.kcalPerBase,
      proteinPerBase: proteinPerBase ?? this.proteinPerBase,
      fatPerBase: fatPerBase ?? this.fatPerBase,
      carbPerBase: carbPerBase ?? this.carbPerBase,
      baseAmount: baseAmount ?? this.baseAmount,
      unitType: unitType ?? this.unitType,
      consumedAmount: consumedAmount ?? this.consumedAmount,
      sourceType: sourceType ?? this.sourceType,
      savedFoodId: savedFoodId ?? this.savedFoodId,
      sourceFoodOwnerUserId:
          sourceFoodOwnerUserId ?? this.sourceFoodOwnerUserId,
      mealGroupId: mealGroupId ?? this.mealGroupId,
      mealGroupName: mealGroupName ?? this.mealGroupName,
      sortOrder: sortOrder ?? this.sortOrder,
      loggedAt: loggedAt ?? this.loggedAt,
    );
  }
}
