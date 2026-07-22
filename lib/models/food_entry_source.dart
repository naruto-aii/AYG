enum FoodEntrySource { manual, savedFood, template, openFoodFacts }

extension FoodEntrySourceX on FoodEntrySource {
  String get storageValue => switch (this) {
    FoodEntrySource.manual => 'manual',
    FoodEntrySource.savedFood => 'saved_food',
    FoodEntrySource.template => 'template',
    FoodEntrySource.openFoodFacts => 'open_food_facts',
  };

  static FoodEntrySource? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    return switch (raw) {
      'manual' => FoodEntrySource.manual,
      'saved_food' => FoodEntrySource.savedFood,
      'template' => FoodEntrySource.template,
      'open_food_facts' => FoodEntrySource.openFoodFacts,
      _ => null,
    };
  }
}
