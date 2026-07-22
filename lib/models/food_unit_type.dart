/// 食品の基準量単位。
enum FoodUnitType { g, ml, piece, serving }

extension FoodUnitTypeX on FoodUnitType {
  String get label => switch (this) {
    FoodUnitType.g => 'g',
    FoodUnitType.ml => 'ml',
    FoodUnitType.piece => '個',
    FoodUnitType.serving => '1食分',
  };

  static FoodUnitType? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return switch (raw.trim()) {
      'g' => FoodUnitType.g,
      'ml' => FoodUnitType.ml,
      'piece' => FoodUnitType.piece,
      'serving' => FoodUnitType.serving,
      _ => null,
    };
  }

  String get storageValue => name;
}
