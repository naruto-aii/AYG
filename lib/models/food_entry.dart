class FoodEntry {
  FoodEntry({
    required this.id,
    required this.name,
    this.kcalPerUnit,
    this.proteinPerUnit,
    this.fatPerUnit,
    this.carbPerUnit,
    required this.quantity,
    required this.loggedAt,
  });

  final String id;
  final String name;
  final double? kcalPerUnit;
  final double? proteinPerUnit;
  final double? fatPerUnit;
  final double? carbPerUnit;
  final double quantity;
  final DateTime loggedAt;

  double get totalKcal => (kcalPerUnit ?? 0) * quantity;
  double get totalProteinG => (proteinPerUnit ?? 0) * quantity;
  double get totalFatG => (fatPerUnit ?? 0) * quantity;
  double get totalCarbG => (carbPerUnit ?? 0) * quantity;

  FoodEntry copyWith({
    String? id,
    String? name,
    double? kcalPerUnit,
    double? proteinPerUnit,
    double? fatPerUnit,
    double? carbPerUnit,
    double? quantity,
    DateTime? loggedAt,
  }) {
    return FoodEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      kcalPerUnit: kcalPerUnit ?? this.kcalPerUnit,
      proteinPerUnit: proteinPerUnit ?? this.proteinPerUnit,
      fatPerUnit: fatPerUnit ?? this.fatPerUnit,
      carbPerUnit: carbPerUnit ?? this.carbPerUnit,
      quantity: quantity ?? this.quantity,
      loggedAt: loggedAt ?? this.loggedAt,
    );
  }
}
