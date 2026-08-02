import 'calculation/energy_target_breakdown.dart';
import 'calculation/macro_target_breakdown.dart';
import 'calculation/remaining_calorie_breakdown.dart';

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
    this.isCalorieOverage = false,
    this.calorieOverageKcal = 0,
    this.energyBreakdown,
    this.macroBreakdown,
    this.remainingBreakdown,
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
  final bool isCalorieOverage;
  final double calorieOverageKcal;
  final EnergyTargetBreakdown? energyBreakdown;
  final MacroTargetBreakdown? macroBreakdown;
  final RemainingCalorieBreakdown? remainingBreakdown;
}
