import '../models/alcohol_entry.dart';
import '../models/exercise_entry.dart';
import '../models/food_entry.dart';

/// 画面に出す kcal は、各行をこの規則で整数にしてから足す。
///
/// 合計を先に丸めると、行の表示を足した数と 1 kcal ずれる。
int displayedKcal(double value) {
  if (!value.isFinite) {
    return 0;
  }
  return value.round();
}

int sumDisplayedKcal(Iterable<double> values) {
  var sum = 0;
  for (final value in values) {
    sum += displayedKcal(value);
  }
  return sum;
}

/// 食事とアルコールの行と同じ整数の合計。kcal が無い食事行は足さない。
int displayedIntakeKcal({
  required Iterable<FoodEntry> foods,
  required Iterable<AlcoholEntry> alcohol,
}) {
  return sumDisplayedKcal([
    for (final food in foods)
      if (food.kcalPerBase != null) food.totalKcal,
    for (final drink in alcohol) drink.totalCalories,
  ]);
}

/// 運動の行と同じ整数に、Health の上乗せを 1 行分として足す。
int displayedBurnKcal({
  required Iterable<ExerciseEntry> exercises,
  double healthExcessKcal = 0,
}) {
  return sumDisplayedKcal([
    for (final entry in exercises) entry.effectiveNetKcal,
    if (healthExcessKcal != 0) healthExcessKcal,
  ]);
}
