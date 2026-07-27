import 'food_unit_type.dart';
import 'meal_template.dart';

class MealTemplateItemDraft {
  const MealTemplateItemDraft({
    this.itemId,
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
  });

  final String? itemId;
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

  MealTemplateItem toItem({required String itemId, required DateTime now}) {
    return MealTemplateItem(
      itemId: itemId,
      savedFoodId: savedFoodId,
      sourceOwnerUserId: sourceOwnerUserId,
      name: name,
      baseAmount: baseAmount,
      unitType: unitType,
      kcalPerBase: kcalPerBase,
      proteinPerBase: proteinPerBase,
      fatPerBase: fatPerBase,
      carbPerBase: carbPerBase,
      consumedAmount: consumedAmount,
      sortOrder: sortOrder,
      snapshotSavedAt: now,
    );
  }

  MealTemplateItemDraft copyWithSortOrder(int sortOrder) {
    return MealTemplateItemDraft(
      itemId: itemId,
      savedFoodId: savedFoodId,
      sourceOwnerUserId: sourceOwnerUserId,
      name: name,
      baseAmount: baseAmount,
      unitType: unitType,
      kcalPerBase: kcalPerBase,
      proteinPerBase: proteinPerBase,
      fatPerBase: fatPerBase,
      carbPerBase: carbPerBase,
      consumedAmount: consumedAmount,
      sortOrder: sortOrder,
    );
  }
}

class MealTemplateDraft {
  const MealTemplateDraft({required this.name, required this.items});

  final String name;
  final List<MealTemplateItemDraft> items;
}

class MealTemplateWithItems {
  const MealTemplateWithItems({required this.template, required this.items});

  final MealTemplate template;
  final List<MealTemplateItem> items;
}
