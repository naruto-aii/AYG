import '../utils/alcohol_unit.dart';

/// 純アルコール量・カロリーの計算結果。
class AlcoholNutritionResult {
  const AlcoholNutritionResult({
    required this.pureAlcoholGrams,
    required this.alcoholCalories,
    required this.totalCalories,
    required this.totalCaloriesIsEstimated,
    required this.canAutoCalculatePureAlcohol,
  });

  final double pureAlcoholGrams;
  final double alcoholCalories;

  /// 摂取カロリーへ加算する確定値。
  final double totalCalories;
  final bool totalCaloriesIsEstimated;
  final bool canAutoCalculatePureAlcohol;
}

/// アルコールの純アルコール量・カロリー計算。
class AlcoholNutritionCalculator {
  static const double alcoholDensityGPerMl = 0.8;
  static const double alcoholKcalPerGram = 7;

  /// ml 単位の純アルコール量 (g) = 飲酒量(ml) × 度数(%) ÷ 100 × 0.8
  static double calculatePureAlcoholGramsFromMl({
    required double amountMl,
    required double alcoholPercentage,
  }) {
    return amountMl * (alcoholPercentage / 100) * alcoholDensityGPerMl;
  }

  /// アルコール由来カロリー (kcal) = 純アルコール量(g) × 7
  static double calculateAlcoholCalories(double pureAlcoholGrams) {
    return pureAlcoholGrams * alcoholKcalPerGram;
  }

  static AlcoholNutritionResult resolve({
    required double amount,
    required String unit,
    required double alcoholPercentage,
    double? totalCaloriesInput,
    double? manualPureAlcoholGrams,
  }) {
    final canAutoCalculate = isMilliliterUnit(unit);
    final pureAlcoholGrams = canAutoCalculate
        ? calculatePureAlcoholGramsFromMl(
            amountMl: amount,
            alcoholPercentage: alcoholPercentage,
          )
        : (manualPureAlcoholGrams ?? 0);
    final alcoholCalories = calculateAlcoholCalories(pureAlcoholGrams);
    final totalCaloriesIsEstimated = totalCaloriesInput == null;
    final totalCalories = totalCaloriesInput ?? alcoholCalories;

    return AlcoholNutritionResult(
      pureAlcoholGrams: pureAlcoholGrams,
      alcoholCalories: alcoholCalories,
      totalCalories: totalCalories,
      totalCaloriesIsEstimated: totalCaloriesIsEstimated,
      canAutoCalculatePureAlcohol: canAutoCalculate,
    );
  }
}
