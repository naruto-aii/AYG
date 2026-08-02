class RemainingCalorieBreakdown {
  const RemainingCalorieBreakdown({
    required this.goalFoodTargetKcal,
    required this.exerciseNetKcal,
    required this.intakeKcal,
    required this.foodKcal,
    required this.alcoholKcal,
    required this.rawRemainingKcal,
  });

  final double goalFoodTargetKcal;
  final double exerciseNetKcal;
  final double intakeKcal;
  final double foodKcal;
  final double alcoholKcal;

  /// `goalFoodTarget + netExercise - intake`（0 へ丸めない）。
  final double rawRemainingKcal;

  bool get isOverage => rawRemainingKcal < 0;

  double get overageKcal => isOverage ? rawRemainingKcal.abs() : 0;

  double get remainingKcal => rawRemainingKcal;
}
