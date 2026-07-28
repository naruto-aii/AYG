import '../models/food_source_type.dart';
import '../models/food_unit_type.dart';
import '../models/food_visibility.dart';

/// 保存済み食品の作成・更新用入力。
class SavedFoodDraft {
  const SavedFoodDraft({
    required this.name,
    required this.baseAmount,
    required this.servingUnitLabel,
    required this.unitType,
    required this.kcalPerBase,
    required this.proteinPerBase,
    required this.fatPerBase,
    required this.carbPerBase,
    this.brand,
    this.barcode,
    this.supplementaryWeight,
    this.sourceType = FoodSourceType.manual,
    this.visibility = FoodVisibility.private,
  });

  final String name;
  final double baseAmount;
  final String servingUnitLabel;
  final FoodUnitType unitType;
  final double? kcalPerBase;
  final double? proteinPerBase;
  final double? fatPerBase;
  final double? carbPerBase;
  final String? brand;
  final String? barcode;
  final String? supplementaryWeight;
  final FoodSourceType sourceType;
  final FoodVisibility visibility;
}
