import 'food_unit_type.dart';
import 'food_visibility.dart';

enum TemplateStatus { active, deleted }

extension TemplateStatusX on TemplateStatus {
  String get storageValue => name;

  static TemplateStatus? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    return switch (raw) {
      'active' => TemplateStatus.active,
      'deleted' => TemplateStatus.deleted,
      _ => null,
    };
  }
}

enum TemplateDependencyStatus { ok, hasUnavailableItems, needsReview }

extension TemplateDependencyStatusX on TemplateDependencyStatus {
  String get storageValue => switch (this) {
    TemplateDependencyStatus.ok => 'ok',
    TemplateDependencyStatus.hasUnavailableItems => 'has_unavailable_items',
    TemplateDependencyStatus.needsReview => 'needs_review',
  };

  static TemplateDependencyStatus? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    return switch (raw) {
      'ok' => TemplateDependencyStatus.ok,
      'has_unavailable_items' => TemplateDependencyStatus.hasUnavailableItems,
      'needs_review' => TemplateDependencyStatus.needsReview,
      _ => null,
    };
  }
}

enum ItemDependencyStatus {
  available,
  sourceDeleted,
  sourceHidden,
  sourceChanged,
}

extension ItemDependencyStatusX on ItemDependencyStatus {
  String get storageValue => switch (this) {
    ItemDependencyStatus.available => 'available',
    ItemDependencyStatus.sourceDeleted => 'source_deleted',
    ItemDependencyStatus.sourceHidden => 'source_hidden',
    ItemDependencyStatus.sourceChanged => 'source_changed',
  };

  static ItemDependencyStatus? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    return switch (raw) {
      'available' => ItemDependencyStatus.available,
      'source_deleted' => ItemDependencyStatus.sourceDeleted,
      'source_hidden' => ItemDependencyStatus.sourceHidden,
      'source_changed' => ItemDependencyStatus.sourceChanged,
      _ => null,
    };
  }
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

  MealTemplate copyWith({
    String? templateId,
    String? ownerUserId,
    String? name,
    String? normalizedName,
    FoodVisibility? visibility,
    TemplateStatus? status,
    double? totalKcal,
    double? totalProteinG,
    double? totalFatG,
    double? totalCarbG,
    TemplateDependencyStatus? dependencyStatus,
    DateTime? lastValidatedAt,
    int? useCount,
    DateTime? lastUsedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return MealTemplate(
      templateId: templateId ?? this.templateId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      visibility: visibility ?? this.visibility,
      status: status ?? this.status,
      totalKcal: totalKcal ?? this.totalKcal,
      totalProteinG: totalProteinG ?? this.totalProteinG,
      totalFatG: totalFatG ?? this.totalFatG,
      totalCarbG: totalCarbG ?? this.totalCarbG,
      dependencyStatus: dependencyStatus ?? this.dependencyStatus,
      lastValidatedAt: lastValidatedAt ?? this.lastValidatedAt,
      useCount: useCount ?? this.useCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
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
