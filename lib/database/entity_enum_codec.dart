import '../models/food_entry_source.dart';
import '../models/food_source_type.dart';
import '../models/food_status.dart';
import '../models/food_unit_type.dart';
import '../models/food_visibility.dart';
import '../models/meal_template.dart';
import '../models/moderation_status.dart';

/// Isar Entity と Domain enum の相互変換。
class EntityEnumCodec {
  const EntityEnumCodec._();

  static int foodUnitTypeIndex(FoodUnitType value) => value.index;

  static FoodUnitType foodUnitTypeFromIndex(int? index) {
    if (index == null || index < 0 || index >= FoodUnitType.values.length) {
      return FoodUnitType.serving;
    }
    return FoodUnitType.values[index];
  }

  static int foodEntrySourceIndex(FoodEntrySource value) => value.index;

  static FoodEntrySource foodEntrySourceFromIndex(int? index) {
    if (index == null || index < 0 || index >= FoodEntrySource.values.length) {
      return FoodEntrySource.manual;
    }
    return FoodEntrySource.values[index];
  }

  static int foodVisibilityIndex(FoodVisibility value) => value.index;

  static FoodVisibility foodVisibilityFromIndex(int index) {
    return FoodVisibility.values[index];
  }

  static int foodStatusIndex(FoodStatus value) => value.index;

  static FoodStatus foodStatusFromIndex(int index) {
    return FoodStatus.values[index];
  }

  static int moderationStatusIndex(ModerationStatus value) {
    return ModerationStatus.values.indexOf(value);
  }

  static ModerationStatus moderationStatusFromIndex(int index) {
    return ModerationStatus.values[index];
  }

  static int foodSourceTypeIndex(FoodSourceType value) => value.index;

  static FoodSourceType foodSourceTypeFromIndex(int index) {
    return FoodSourceType.values[index];
  }

  static int templateStatusIndex(TemplateStatus value) => value.index;

  static TemplateStatus templateStatusFromIndex(int index) {
    return TemplateStatus.values[index];
  }

  static int templateDependencyStatusIndex(TemplateDependencyStatus value) {
    return TemplateDependencyStatus.values.indexOf(value);
  }

  static TemplateDependencyStatus templateDependencyStatusFromIndex(int index) {
    return TemplateDependencyStatus.values[index];
  }

  static int itemDependencyStatusIndex(ItemDependencyStatus value) {
    return ItemDependencyStatus.values.indexOf(value);
  }

  static ItemDependencyStatus itemDependencyStatusFromIndex(int index) {
    return ItemDependencyStatus.values[index];
  }
}
