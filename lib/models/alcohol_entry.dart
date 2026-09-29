/// アルコール記録エントリ。
class AlcoholEntry {
  AlcoholEntry({
    required this.id,
    required this.beverageName,
    required this.amount,
    required this.unit,
    required this.alcoholPercentage,
    required this.totalCalories,
    required this.pureAlcoholGrams,
    required this.alcoholCalories,
    required this.consumedAt,
  });

  final String id;
  final String beverageName;
  final double amount;
  final String unit;
  final double alcoholPercentage;

  /// 1日の摂取カロリーへ加算する確定値（飲料全体）。
  final double totalCalories;

  /// 参考値。摂取カロリーへは加算しない。
  final double pureAlcoholGrams;

  /// 参考値（純アルコール × 7 kcal/g）。摂取カロリーへは加算しない。
  final double alcoholCalories;
  final DateTime consumedAt;

  AlcoholEntry copyWith({
    String? id,
    String? beverageName,
    double? amount,
    String? unit,
    double? alcoholPercentage,
    double? totalCalories,
    double? pureAlcoholGrams,
    double? alcoholCalories,
    DateTime? consumedAt,
  }) {
    return AlcoholEntry(
      id: id ?? this.id,
      beverageName: beverageName ?? this.beverageName,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      alcoholPercentage: alcoholPercentage ?? this.alcoholPercentage,
      totalCalories: totalCalories ?? this.totalCalories,
      pureAlcoholGrams: pureAlcoholGrams ?? this.pureAlcoholGrams,
      alcoholCalories: alcoholCalories ?? this.alcoholCalories,
      consumedAt: consumedAt ?? this.consumedAt,
    );
  }
}
