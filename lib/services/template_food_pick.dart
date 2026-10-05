import '../models/food_unit_type.dart';
import '../models/meal_template_draft.dart';
import '../models/official_food.dart';

/// 食品成分表の1件を、テンプレートの行にする。
///
/// 成分表の番号はテンプレートの行には残さない。栄養は選んだ時点の値を写す。
MealTemplateItemDraft templateItemFromOfficialFood(
  OfficialFoodMatch match, {
  required double consumedAmount,
  required int sortOrder,
}) {
  final base = match.baseAmount <= 0 ? 100.0 : match.baseAmount;
  final amount = consumedAmount <= 0 ? base : consumedAmount;
  return MealTemplateItemDraft(
    name: match.listTitle,
    baseAmount: base,
    unitType: FoodUnitTypeX.tryParse(match.unitType) ?? FoodUnitType.g,
    kcalPerBase: match.kcal,
    proteinPerBase: match.proteinG,
    fatPerBase: match.fatG,
    carbPerBase: match.carbG,
    consumedAmount: amount,
    sortOrder: sortOrder,
  );
}
