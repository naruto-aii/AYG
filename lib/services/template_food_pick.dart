import '../models/food_unit_type.dart';
import '../models/meal_template_draft.dart';
import '../models/official_food.dart';
import 'photo_meal.dart';

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

/// AI検索や外食・コンビニで確認した食品を、テンプレートの行にする。
///
/// 食事記録と同じく、確認した合計を基準量と摂取量の両方に入れる。
/// 画面の合計はもう一度掛けない。
MealTemplateItemDraft templateItemFromConfirmedFood(
  ConfirmedFoodCapture capture, {
  required int sortOrder,
}) {
  final parsed = parsePhotoAmount(capture.amountText);
  return MealTemplateItemDraft(
    name: capture.name.trim(),
    baseAmount: parsed.amount,
    unitType: parsed.unit,
    kcalPerBase: capture.kcal,
    proteinPerBase: capture.proteinG,
    fatPerBase: capture.fatG,
    carbPerBase: capture.carbG,
    consumedAmount: parsed.amount,
    sortOrder: sortOrder,
  );
}
