class DailySummary {
  DailySummary({
    required this.targetKcal,
    required this.remainingKcal,
    required this.targetProteinG,
    required this.targetFatG,
    required this.targetCarbG,
    required this.intakeKcal,
    required this.intakeProteinG,
    required this.intakeFatG,
    required this.intakeCarbG,
    required this.exerciseBurnKcal,
  });

  final double targetKcal;
  final double remainingKcal;
  final double targetProteinG;
  final double targetFatG;
  final double targetCarbG;
  final double intakeKcal;
  final double intakeProteinG;
  final double intakeFatG;
  final double intakeCarbG;
  final double exerciseBurnKcal;
}
