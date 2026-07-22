enum FoodVisibility { private, public, unlisted }

extension FoodVisibilityX on FoodVisibility {
  static FoodVisibility? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    for (final value in FoodVisibility.values) {
      if (value.name == raw) {
        return value;
      }
    }
    return null;
  }
}
