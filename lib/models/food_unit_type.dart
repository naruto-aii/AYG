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

  /// 自由入力の基準単位から DB 制約用 enum へ変換する。
  static FoodUnitType inferFromUnitLabel(String unitLabel) {
    final unit = unitLabel.trim();
    return switch (unit) {
      'g' => FoodUnitType.g,
      'ml' => FoodUnitType.ml,
      '個' => FoodUnitType.piece,
      _ => FoodUnitType.serving,
    };
  }
}
