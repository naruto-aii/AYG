import '../models/meal_template.dart';

class MealTemplateTotalsService {
  const MealTemplateTotalsService();

  ({double kcal, double protein, double fat, double carb}) totalsFromItems(
    List<MealTemplateItem> items,
  ) {
    var kcal = 0.0;
    var protein = 0.0;
    var fat = 0.0;
    var carb = 0.0;
    for (final item in items) {
      kcal += item.totalKcal;
      protein += item.totalProteinG;
      fat += item.totalFatG;
      carb += item.totalCarbG;
    }
    return (kcal: kcal, protein: protein, fat: fat, carb: carb);
  }
}
