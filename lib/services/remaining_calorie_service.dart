import '../models/alcohol_entry.dart';
import '../models/calculation/remaining_calorie_breakdown.dart';
import '../models/exercise_entry.dart';
import '../models/food_entry.dart';
import '../utils/local_date.dart';

/// 日次「あと x kcal」の単一計算源。
class RemainingCalorieService {
  const RemainingCalorieService();

  /// remaining = baseDailyFoodTarget + sum(netExercise) - sum(intake)
  double calculate({
    required double baseDailyFoodTargetKcal,
    required double intakeKcal,
    required double exerciseNetKcal,
  }) {
    if (!baseDailyFoodTargetKcal.isFinite ||
        !intakeKcal.isFinite ||
        !exerciseNetKcal.isFinite) {
      return double.nan;
    }
    return baseDailyFoodTargetKcal + exerciseNetKcal - intakeKcal;
  }

  RemainingCalorieBreakdown calculateBreakdown({
    required double baseDailyFoodTargetKcal,
    required List<FoodEntry> foodEntries,
    required List<AlcoholEntry> alcoholEntries,
    required List<ExerciseEntry> exerciseEntries,
    required DateTime selectedDay,
  }) {
    final foodKcal = _sumFoodKcal(foodEntries, selectedDay);
    final alcoholKcal = _sumAlcoholKcal(alcoholEntries, selectedDay);
    final intakeKcal = foodKcal + alcoholKcal;
    final exerciseNetKcal = sumExerciseNetKcal(
      exerciseEntries: exerciseEntries,
      selectedDay: selectedDay,
    );
    final raw = calculate(
      baseDailyFoodTargetKcal: baseDailyFoodTargetKcal,
      intakeKcal: intakeKcal,
      exerciseNetKcal: exerciseNetKcal,
    );
    return RemainingCalorieBreakdown(
      goalFoodTargetKcal: baseDailyFoodTargetKcal,
      exerciseNetKcal: exerciseNetKcal,
      intakeKcal: intakeKcal,
      foodKcal: foodKcal,
      alcoholKcal: alcoholKcal,
      rawRemainingKcal: raw,
    );
  }

  double sumIntakeKcal({
    required List<FoodEntry> foodEntries,
    required List<AlcoholEntry> alcoholEntries,
    required DateTime selectedDay,
  }) {
    return _sumFoodKcal(foodEntries, selectedDay) +
        _sumAlcoholKcal(alcoholEntries, selectedDay);
  }

  double sumExerciseNetKcal({
    required List<ExerciseEntry> exerciseEntries,
    required DateTime selectedDay,
  }) {
    final dayExercise = filterLoggedOnLocalDay(
      entries: exerciseEntries,
      referenceDate: selectedDay,
      readLoggedAt: (entry) => entry.loggedAt,
    );
    return dayExercise.fold<double>(
      0,
      (sum, entry) => sum + entry.effectiveNetKcal,
    );
  }

  double _sumFoodKcal(List<FoodEntry> entries, DateTime selectedDay) {
    final dayFood = filterLoggedOnLocalDay(
      entries: entries,
      referenceDate: selectedDay,
      readLoggedAt: (entry) => entry.loggedAt,
    );
    return dayFood.fold<double>(0, (sum, entry) => sum + entry.totalKcal);
  }

  double _sumAlcoholKcal(List<AlcoholEntry> entries, DateTime selectedDay) {
    final dayAlcohol = filterLoggedOnLocalDay(
      entries: entries,
      referenceDate: selectedDay,
      readLoggedAt: (entry) => entry.consumedAt,
    );
    return dayAlcohol.fold<double>(
      0,
      (sum, entry) => sum + entry.totalCalories,
    );
  }
}
