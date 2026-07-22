enum FoodSourceType { manual, openFoodFacts, openFoodFactsDerived, copied }

extension FoodSourceTypeX on FoodSourceType {
  String get storageValue => switch (this) {
    FoodSourceType.manual => 'manual',
    FoodSourceType.openFoodFacts => 'open_food_facts',
    FoodSourceType.openFoodFactsDerived => 'open_food_facts_derived',
    FoodSourceType.copied => 'copied',
  };

  static FoodSourceType? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    return switch (raw) {
      'manual' => FoodSourceType.manual,
      'open_food_facts' => FoodSourceType.openFoodFacts,
      'open_food_facts_derived' => FoodSourceType.openFoodFactsDerived,
      'copied' => FoodSourceType.copied,
      _ => null,
    };
  }
}
