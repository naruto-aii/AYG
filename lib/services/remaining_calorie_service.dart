import '../models/alcohol_entry.dart';
import '../models/exercise_entry.dart';
import '../models/food_entry.dart';
import '../utils/local_date.dart';

/// 日次「あと x kcal」の単一計算源。
class RemainingCalorieService {
  const RemainingCalorieService();

  /// remaining = baseDailyFoodTarget + sum(netExercise) - sum(intake)
  ///
  /// [intake] には食事・飲料・アルコール由来カロリーを含める。
  /// [exerciseNetKcal] には運動の net のみを渡す。
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

  double sumIntakeKcal({
    required List<FoodEntry> foodEntries,
    required List<AlcoholEntry> alcoholEntries,
    required DateTime selectedDay,
  }) {
    final dayFood = filterLoggedOnLocalDay(
      entries: foodEntries,
      referenceDate: selectedDay,
      readLoggedAt: (entry) => entry.loggedAt,
    );
    final dayAlcohol = filterLoggedOnLocalDay(
      entries: alcoholEntries,
      referenceDate: selectedDay,
      readLoggedAt: (entry) => entry.consumedAt,
    );

    final foodKcal = dayFood.fold<double>(
      0,
      (sum, entry) => sum + entry.totalKcal,
    );
    final alcoholKcal = dayAlcohol.fold<double>(
      0,
      (sum, entry) => sum + entry.totalCalories,
    );
    return foodKcal + alcoholKcal;
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
}
