/// 計算ロジックのバージョン識別子。
class CalculationVersions {
  CalculationVersions._();

  static const energy = 'energy_v3';
  static const macro = 'macro_v2';
  static const exerciseMet = 'exercise_met_v2';

  /// 距離（km）× 体重の追加消費。MET×時間とは別。
  static const exerciseDistance = 'exercise_distance_v1';

  /// 回数を時間に直してから MET×時間。
  static const exerciseReps = 'exercise_reps_v1';
}
