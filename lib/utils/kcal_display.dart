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
  return displayedFoodKcal(foods) + displayedAlcoholKcal(alcohol);
}

/// 一覧で、Health と重なって消費に足さない行。数字は出さない。
const String overlappedExerciseLabel = '重複';

/// 運動の行に出す文字。重なる行は [overlappedExerciseLabel]。それ以外は整数。
String displayedExerciseRow(double netKcal, {required bool overlapped}) {
  if (overlapped) {
    return overlappedExerciseLabel;
  }
  return '+${displayedKcal(netKcal)}';
}

/// 運動の行と同じ整数に、Health の上乗せを 1 行分として足す。
///
/// [exercises] は、Health と重なる行を除いたあとのリスト。
/// 画面の消費は、この整数と Health の整数の和。
int displayedBurnKcal({
  required Iterable<ExerciseEntry> exercises,
  double healthExcessKcal = 0,
}) {
  return displayedExerciseKcal(exercises) +
      displayedHealthKcal(healthExcessKcal);
}

int displayedFoodKcal(Iterable<FoodEntry> foods) {
  return sumDisplayedKcal([
    for (final food in foods)
      if (food.kcalPerBase != null) food.totalKcal,
  ]);
}

int displayedAlcoholKcal(Iterable<AlcoholEntry> alcohol) {
  return sumDisplayedKcal([
    for (final drink in alcohol) drink.totalCalories,
  ]);
}

int displayedExerciseKcal(Iterable<ExerciseEntry> exercises) {
  return sumDisplayedKcal([
    for (final entry in exercises) entry.effectiveNetKcal,
  ]);
}

/// 0 は行として出さない。出るときだけ、その 1 行を整数にする。
int displayedHealthKcal(double healthExcessKcal) {
  if (healthExcessKcal == 0) {
    return 0;
  }
  return displayedKcal(healthExcessKcal);
}

/// 画面の目標・摂取・消費と同じ整数から作った、その日の残り。
///
/// 残り = 目標の整数 + 消費の整数 − 摂取の整数。負なら超過。
/// 生の残りを丸めた数は、行を足した数と 1 kcal ずれることがある。
class DisplayedDayKcal {
  const DisplayedDayKcal({
    required this.target,
    required this.food,
    required this.alcohol,
    required this.exercise,
    required this.health,
  });

  final int target;
  final int food;
  final int alcohol;
  final int exercise;
  final int health;

  int get intake => food + alcohol;

  int get burn => exercise + health;

  /// 正が残り、負が超過。
  int get remaining => target + burn - intake;

  int get remainingShown => remaining < 0 ? 0 : remaining;

  int get overageShown => remaining < 0 ? -remaining : 0;

  bool get isOverage => remaining < 0;
}

DisplayedDayKcal displayedDayKcal({
  required double targetKcal,
  required Iterable<FoodEntry> foods,
  required Iterable<AlcoholEntry> alcohol,
  required Iterable<ExerciseEntry> exercises,
  double healthExcessKcal = 0,
}) {
  return DisplayedDayKcal(
    target: displayedKcal(targetKcal),
    food: displayedFoodKcal(foods),
    alcohol: displayedAlcoholKcal(alcohol),
    exercise: displayedExerciseKcal(exercises),
    health: displayedHealthKcal(healthExcessKcal),
  );
}
