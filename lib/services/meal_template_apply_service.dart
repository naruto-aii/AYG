import '../models/food_entry.dart';
import '../models/food_entry_source.dart';
import '../models/meal_template.dart';
import '../models/meal_template_apply.dart';

class MealTemplateApplyService {
  const MealTemplateApplyService();

  List<FoodEntry> buildEntries({
    required List<MealTemplateItem> items,
    required String mealGroupId,
    required String mealGroupName,
    required DateTime loggedAt,
    required String Function() generateEntryId,
  }) {
    final entries = <FoodEntry>[];
    for (final item in items) {
      entries.add(
        FoodEntry(
          id: generateEntryId(),
          name: item.name,
          kcalPerBase: item.kcalPerBase,
          proteinPerBase: item.proteinPerBase,
          fatPerBase: item.fatPerBase,
          carbPerBase: item.carbPerBase,
          baseAmount: item.baseAmount,
          unitType: item.unitType,
          consumedAmount: item.consumedAmount,
          sourceType: item.savedFoodId == null
              ? FoodEntrySource.manual
              : FoodEntrySource.savedFood,
          savedFoodId: item.savedFoodId,
          sourceFoodOwnerUserId: item.sourceOwnerUserId,
          mealGroupId: mealGroupId,
          mealGroupName: mealGroupName,
          sortOrder: item.sortOrder,
          loggedAt: loggedAt,
        ),
      );
    }
    return entries;
  }

  List<MealTemplateItem> resolveItems({
    required List<MealTemplateItem> originalItems,
    required List<MealTemplateItemResolution> resolutions,
  }) {
    if (resolutions.any(
      (resolution) =>
          resolution.action == MealTemplateItemResolutionAction.cancel,
    )) {
      return const [];
    }

    final resolutionByItemId = {
      for (final resolution in resolutions) resolution.itemId: resolution,
    };

    final resolved = <MealTemplateItem>[];
    for (final item in originalItems) {
      final resolution = resolutionByItemId[item.itemId];
      if (resolution == null) {
        resolved.add(item);
        continue;
      }

      switch (resolution.action) {
        case MealTemplateItemResolutionAction.useSnapshot:
          resolved.add(item);
        case MealTemplateItemResolutionAction.copyToPrivate:
        case MealTemplateItemResolutionAction.replace:
          final replacement = resolution.replacement;
          if (replacement != null) {
            resolved.add(replacement);
          }
        case MealTemplateItemResolutionAction.exclude:
          continue;
        case MealTemplateItemResolutionAction.cancel:
          return const [];
      }
    }
    return resolved;
  }
}
