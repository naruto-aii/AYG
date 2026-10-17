import '../data/met_activity_catalog.dart';
import '../models/exercise_entry.dart';
import '../models/exercise_quantity_unit.dart';
import 'exercise_calorie_calculator.dart';

/// その種目のカロリー式が使う入力の欄名。
String exerciseQuantityPrompt(ExerciseQuantityUnit unit) {
  return switch (unit) {
    ExerciseQuantityUnit.distanceKm => '距離（km）',
    ExerciseQuantityUnit.reps => '回数',
    ExerciseQuantityUnit.durationMin => '実施時間（分）',
  };
}

/// 距離の式なのに、速度が無くて分カラムだけ 1 になっている記録。
///
/// カロリーは距離から決まっている。この 1 分はユーザーが運動した時間ではない。
bool distanceDurationIsPlaceholder(ExerciseEntry entry) {
  final activity = MetActivityCatalog.findById(entry.activityId);
  if (activity == null ||
      activity.quantityUnit != ExerciseQuantityUnit.distanceKm) {
    return false;
  }
  final km = entry.distanceKm;
  if (km == null || km <= 0) {
    return false;
  }
  final speed = activity.speedFor(entry.intensity);
  if (speed != null && speed > 0) {
    return false;
  }
  return entry.durationMin ==
      ExerciseCalorieCalculator.companionDurationMin(
        distanceKm: km,
        referenceSpeedKmh: null,
      );
}
