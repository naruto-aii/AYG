import '../models/exercise_entry.dart';
import '../models/health_profile_data.dart';
import '../utils/local_date.dart';
import '../utils/record_clock.dart';
import 'exercise_duration.dart';

/// Health のアクティブエネルギーと、手入力の運動を二重に足さない。
///
/// 規則:
/// - その日に Health のアクティブエネルギーが無い（連携オフ、または値が null）
///   ときは、手入力の運動をこれまでどおり全部足す。
/// - アクティブエネルギーがある日は、Health の上乗せが消費の本体になる。
///   手入力は、その日の Health ワークアウトの時間範囲と重ならないものだけ足す。
///   重なる手入力は Health に含まれているものとして足さない。
/// - 時間範囲は手入力の記録時刻から実施分まで。距離だけで分が仮の 1 分の記録は、
///   幅を作らず、記録時刻がそのワークアウトの中にあるときだけ重なるとみなす。
/// - ワークアウトが 1 件も無い日は、重なる相手が無いので手入力は全部足す。
/// - 片方しか無い日は、これまでと同じ（手入力だけ、または Health の上乗せだけ）。
class HealthExerciseCredit {
  const HealthExerciseCredit();

  static bool rangesOverlap({
    required DateTime manualStart,
    required DateTime manualEnd,
    required DateTime workoutStart,
    required DateTime workoutEnd,
  }) {
    final start = civilClock(manualStart);
    final end = civilClock(manualEnd);
    final otherStart = civilClock(workoutStart);
    final otherEnd = civilClock(workoutEnd);
    if (!end.isAfter(start) || !otherEnd.isAfter(otherStart)) {
      return false;
    }
    return start.isBefore(otherEnd) && otherStart.isBefore(end);
  }

  static bool manualOverlapsWorkout(
    ExerciseEntry entry,
    HealthWorkoutRecord workout,
  ) {
    final start = entry.loggedAt;
    if (distanceDurationIsPlaceholder(entry)) {
      final point = civilClock(start);
      final otherStart = civilClock(workout.startTime);
      final otherEnd = civilClock(workout.endTime);
      return !point.isBefore(otherStart) && point.isBefore(otherEnd);
    }
    final end = start.add(Duration(minutes: entry.durationMin));
    return rangesOverlap(
      manualStart: start,
      manualEnd: end,
      workoutStart: workout.startTime,
      workoutEnd: workout.endTime,
    );
  }

  /// 残りと画面の消費に足す手入力。重なる行は除く。
  List<ExerciseEntry> creditedManualExercises({
    required bool healthActiveEnergyPresent,
    required List<ExerciseEntry> dayExercises,
    required List<HealthWorkoutRecord> healthWorkouts,
  }) {
    if (!healthActiveEnergyPresent) {
      return List<ExerciseEntry>.of(dayExercises);
    }
    return [
      for (final entry in dayExercises)
        if (!manualIsOverlapped(
          entry: entry,
          healthActiveEnergyPresent: true,
          healthWorkouts: healthWorkouts,
        ))
          entry,
    ];
  }

  /// Health のワークアウトと重なり、消費に足さない行か。
  bool manualIsOverlapped({
    required ExerciseEntry entry,
    required bool healthActiveEnergyPresent,
    required List<HealthWorkoutRecord> healthWorkouts,
  }) {
    if (!healthActiveEnergyPresent) {
      return false;
    }
    return healthWorkouts.any(
      (workout) => manualOverlapsWorkout(entry, workout),
    );
  }

  /// 残りカロリーに足す手入力の net。日で絞ったあとのリストを渡す。
  double creditedManualNetKcal({
    required bool healthActiveEnergyPresent,
    required List<ExerciseEntry> dayExercises,
    required List<HealthWorkoutRecord> healthWorkouts,
  }) {
    return creditedManualExercises(
      healthActiveEnergyPresent: healthActiveEnergyPresent,
      dayExercises: dayExercises,
      healthWorkouts: healthWorkouts,
    ).fold<double>(0, (sum, entry) => sum + entry.effectiveNetKcal);
  }

  List<ExerciseEntry> exercisesOnDay(
    List<ExerciseEntry> entries,
    DateTime selectedDay,
  ) {
    return filterLoggedOnLocalDay(
      entries: entries,
      referenceDate: selectedDay,
      readLoggedAt: (entry) => entry.loggedAt,
    );
  }
}
