import '../constants/official_food_copy.dart';
import '../models/food_entry.dart';
import '../models/food_entry_source.dart';
import '../models/food_source_type.dart';
import '../models/food_unit_type.dart';
import '../models/official_food.dart';
import '../models/saved_food_draft.dart';

/// 成分表の100g値を、食べた量の食事記録と非公開のマイ食品に写す。
class OfficialFoodLogger {
  const OfficialFoodLogger();

  FoodEntry buildEntry({
    required OfficialFoodMatch match,
    required String entryId,
    required double grams,
    required DateTime loggedAt,
  }) {
    return FoodEntry(
      id: entryId,
      name: match.listTitle,
      kcalPerBase: match.kcal,
      proteinPerBase: match.proteinG,
      fatPerBase: match.fatG,
      carbPerBase: match.carbG,
      baseAmount: match.baseAmount <= 0 ? 100 : match.baseAmount,
      unitType: FoodUnitType.g,
      consumedAmount: grams,
      sourceType: FoodEntrySource.mextSfct,
      officialFoodCode: match.foodCode,
      officialFoodName: match.name,
      loggedAt: loggedAt,
    );
  }

  SavedFoodDraft buildDraft(OfficialFoodMatch match) {
    final alias = match.matchedAlias?.trim();
    final showsAlias = alias != null && alias.isNotEmpty && alias != match.name;
    return SavedFoodDraft(
      name: match.listTitle,
      baseAmount: match.baseAmount <= 0 ? 100 : match.baseAmount,
      servingUnitLabel: 'g',
      unitType: FoodUnitType.g,
      kcalPerBase: match.kcal,
      proteinPerBase: match.proteinG,
      fatPerBase: match.fatG,
      carbPerBase: match.carbG,
      brand: showsAlias ? match.name : null,
      officialFoodCode: match.foodCode,
      officialFoodName: match.name,
      sourceAttribution: OfficialFoodCopy.fullAttribution,
      sourceType: FoodSourceType.mextSfct,
    );
  }

  double? scaled(double? perBase, double grams, double baseAmount) {
    if (perBase == null || baseAmount <= 0) {
      return null;
    }
    return perBase * grams / baseAmount;
  }
}
