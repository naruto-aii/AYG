enum FoodStatus { active, deleted, suspended }

extension FoodStatusX on FoodStatus {
  static FoodStatus? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    for (final value in FoodStatus.values) {
      if (value.name == raw) {
        return value;
      }
    }
    return null;
  }
}
