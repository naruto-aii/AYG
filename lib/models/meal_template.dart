import 'food_unit_type.dart';
import 'food_visibility.dart';

enum TemplateStatus { active, deleted }

enum TemplateDependencyStatus { ok, hasUnavailableItems, needsReview }

enum ItemDependencyStatus {
  available,
  sourceDeleted,
  sourceHidden,
  sourceChanged,
}

/// Version 1.1 では private のみ。
class MealTemplate {
  MealTemplate({
    required this.templateId,
    required this.ownerUserId,
    required this.name,
    required this.normalizedName,
    this.visibility = FoodVisibility.private,
    this.status = TemplateStatus.active,
    required this.totalKcal,
    required this.totalProteinG,
    required this.totalFatG,
    required this.totalCarbG,
    this.dependencyStatus = TemplateDependencyStatus.ok,
    this.lastValidatedAt,
    this.useCount = 0,
    this.lastUsedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String templateId;
  final String ownerUserId;
  final String name;
  final String normalizedName;
  final FoodVisibility visibility;
  final TemplateStatus status;

  final double totalKcal;
  final double totalProteinG;
  final double totalFatG;
  final double totalCarbG;

  final TemplateDependencyStatus dependencyStatus;
  final DateTime? lastValidatedAt;

  final int useCount;
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}

class MealTemplateItem {
  MealTemplateItem({
    required this.itemId,
    this.savedFoodId,
    this.sourceOwnerUserId,
    required this.name,
    required this.baseAmount,
    required this.unitType,
    this.kcalPerBase,
    this.proteinPerBase,
    this.fatPerBase,
    this.carbPerBase,
    required this.consumedAmount,
    required this.sortOrder,
    this.itemDependencyStatus = ItemDependencyStatus.available,
    required this.snapshotSavedAt,
  }) : assert(baseAmount > 0, 'baseAmount must be positive'),
       assert(consumedAmount > 0, 'consumedAmount must be positive');

  final String itemId;
  final String? savedFoodId;
  final String? sourceOwnerUserId;

  final String name;
  final double baseAmount;
  final FoodUnitType unitType;
  final double? kcalPerBase;
  final double? proteinPerBase;
  final double? fatPerBase;
  final double? carbPerBase;
  final double consumedAmount;
  final int sortOrder;

  final ItemDependencyStatus itemDependencyStatus;
  final DateTime snapshotSavedAt;

  double get multiplier => consumedAmount / baseAmount;

  double get totalKcal => (kcalPerBase ?? 0) * multiplier;
  double get totalProteinG => (proteinPerBase ?? 0) * multiplier;
  double get totalFatG => (fatPerBase ?? 0) * multiplier;
  double get totalCarbG => (carbPerBase ?? 0) * multiplier;
}
