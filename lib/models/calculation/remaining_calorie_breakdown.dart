class RemainingCalorieBreakdown {
  const RemainingCalorieBreakdown({
    required this.goalFoodTargetKcal,
    required this.exerciseNetKcal,
    required this.intakeKcal,
    required this.foodKcal,
    required this.alcoholKcal,
    required this.rawRemainingKcal,
    this.healthActivityExcessKcal = 0,
  });

  final double goalFoodTargetKcal;
  final double exerciseNetKcal;

  /// Health のアクティブエネルギーのうち、生活活動係数を超えた分。
  final double healthActivityExcessKcal;

  /// 画面の消費。記録した運動と、連携時の上乗せ。
  double get screenBurnKcal => exerciseNetKcal + healthActivityExcessKcal;
  final double intakeKcal;
  final double foodKcal;
  final double alcoholKcal;

  /// `goalFoodTarget + netExercise - intake`（0 へ丸めない）。
  final double rawRemainingKcal;

  bool get isOverage => rawRemainingKcal < 0;

  double get overageKcal => isOverage ? rawRemainingKcal.abs() : 0;

  double get remainingKcal => rawRemainingKcal;
}
