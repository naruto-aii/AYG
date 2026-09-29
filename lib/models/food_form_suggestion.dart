import 'meal_template.dart';
import 'saved_food.dart';

/// 食事登録フォームの検索候補（保存済み食品 / 食事テンプレート）。
sealed class FoodFormSuggestion {
  const FoodFormSuggestion();
}

class SavedFoodFormSuggestion extends FoodFormSuggestion {
  const SavedFoodFormSuggestion(this.food);

  final SavedFood food;
}

class MealTemplateFormSuggestion extends FoodFormSuggestion {
  const MealTemplateFormSuggestion(this.template, {required this.itemCount});

  final MealTemplate template;
  final int itemCount;
}
