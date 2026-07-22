import '../utils/base_amount_normalizer.dart';
import '../utils/food_name_normalizer.dart';
import 'food_source_type.dart';
import 'food_status.dart';
import 'food_unit_type.dart';
import 'food_visibility.dart';
import 'moderation_status.dart';

/// 再利用可能な食品マスター（private / public 共通）。
class SavedFood {
  SavedFood({
    required this.foodId,
    required this.ownerUserId,
    required this.name,
    required this.normalizedName,
    required this.baseAmount,
    required this.unitType,
    this.visibility = FoodVisibility.private,
    this.status = FoodStatus.active,
    this.moderationStatus = ModerationStatus.none,
    this.kcalPerBase,
    this.proteinPerBase,
    this.fatPerBase,
    this.carbPerBase,
    this.sourceType = FoodSourceType.manual,
    this.barcode,
    this.brand,
    this.supplementaryWeight,
    this.copiedFromFoodId,
    this.copiedFromOwnerUserId,
    this.useCount = 0,
    this.lastUsedAt,
    this.reportCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  }) : assert(baseAmount > 0, 'baseAmount must be positive');

  final String foodId;
  final String ownerUserId;
  final FoodVisibility visibility;
  final FoodStatus status;
  final ModerationStatus moderationStatus;

  final String name;
  final String normalizedName;

  final double baseAmount;
  final FoodUnitType unitType;

  final double? kcalPerBase;
  final double? proteinPerBase;
  final double? fatPerBase;
  final double? carbPerBase;

  final FoodSourceType sourceType;
  final String? barcode;
  final String? brand;
  final String? supplementaryWeight;

  final String? copiedFromFoodId;
  final String? copiedFromOwnerUserId;

  final int useCount;
  final DateTime? lastUsedAt;
  final int reportCount;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isPublicActive =>
      visibility == FoodVisibility.public &&
      status == FoodStatus.active &&
      deletedAt == null &&
      moderationStatus != ModerationStatus.hidden &&
      moderationStatus != ModerationStatus.suspended;

  SavedFood copyWith({
    String? foodId,
    String? ownerUserId,
    FoodVisibility? visibility,
    FoodStatus? status,
    ModerationStatus? moderationStatus,
    String? name,
    String? normalizedName,
    double? baseAmount,
    FoodUnitType? unitType,
    double? kcalPerBase,
    double? proteinPerBase,
    double? fatPerBase,
    double? carbPerBase,
    FoodSourceType? sourceType,
    String? barcode,
    String? brand,
    String? supplementaryWeight,
    String? copiedFromFoodId,
    String? copiedFromOwnerUserId,
    int? useCount,
    DateTime? lastUsedAt,
    int? reportCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return SavedFood(
      foodId: foodId ?? this.foodId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      visibility: visibility ?? this.visibility,
      status: status ?? this.status,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      baseAmount: baseAmount ?? this.baseAmount,
      unitType: unitType ?? this.unitType,
      kcalPerBase: kcalPerBase ?? this.kcalPerBase,
      proteinPerBase: proteinPerBase ?? this.proteinPerBase,
      fatPerBase: fatPerBase ?? this.fatPerBase,
      carbPerBase: carbPerBase ?? this.carbPerBase,
      sourceType: sourceType ?? this.sourceType,
      barcode: barcode ?? this.barcode,
      brand: brand ?? this.brand,
      supplementaryWeight: supplementaryWeight ?? this.supplementaryWeight,
      copiedFromFoodId: copiedFromFoodId ?? this.copiedFromFoodId,
      copiedFromOwnerUserId:
          copiedFromOwnerUserId ?? this.copiedFromOwnerUserId,
      useCount: useCount ?? this.useCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      reportCount: reportCount ?? this.reportCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  /// 保存前に baseAmount と normalizedName を正規化する。
  SavedFood normalizedForSave() {
    return copyWith(
      baseAmount: BaseAmountNormalizer.normalize(baseAmount),
      normalizedName: FoodNameNormalizer.normalize(name),
    );
  }
}
