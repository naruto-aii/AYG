import '../../models/activity_level.dart';
import '../../models/goal.dart';
import 'calculation_versions.dart';
import 'goal_pace.dart';

/// 1日の食事目標カロリーまでの中間値。
class EnergyTargetBreakdown {
  const EnergyTargetBreakdown({
    required this.version,
    required this.ageYears,
    required this.heightCm,
    required this.weightKg,
    required this.genderLabel,
    required this.canEstimateRee,
    required this.unavailableReason,
    required this.estimatedReeKcal,
    required this.lifestyleActivityLevel,
    required this.lifestyleActivityLabel,
    required this.lifestyleActivityFactor,
    required this.estimatedMaintenanceKcal,
    required this.goalType,
    required this.goalPace,
    required this.dailyGoalAdjustmentKcal,
    required this.goalFoodTargetKcal,
    required this.usedHealthActiveEnergyForTarget,
    required this.healthActiveEnergyKcal,
    required this.productDefaultsUsed,
    required this.calculatedAt,
  });

  final String version;
  final int? ageYears;
  final double? heightCm;
  final double? weightKg;
  final String genderLabel;
  final bool canEstimateRee;
  final String? unavailableReason;
  final double? estimatedReeKcal;
  final ActivityLevel? lifestyleActivityLevel;
  final String? lifestyleActivityLabel;
  final double? lifestyleActivityFactor;
  final double? estimatedMaintenanceKcal;
  final GoalType goalType;
  final GoalPace goalPace;
  final double dailyGoalAdjustmentKcal;
  final double? goalFoodTargetKcal;
  final bool usedHealthActiveEnergyForTarget;
  final double? healthActiveEnergyKcal;
  final List<String> productDefaultsUsed;
  final DateTime calculatedAt;

  static EnergyTargetBreakdown unavailable({
    required String reason,
    required GoalType goalType,
    GoalPace goalPace = GoalPace.standard,
  }) {
    return EnergyTargetBreakdown(
      version: CalculationVersions.energy,
      ageYears: null,
      heightCm: null,
      weightKg: null,
      genderLabel: '',
      canEstimateRee: false,
      unavailableReason: reason,
      estimatedReeKcal: null,
      lifestyleActivityLevel: null,
      lifestyleActivityLabel: null,
      lifestyleActivityFactor: null,
      estimatedMaintenanceKcal: null,
      goalType: goalType,
      goalPace: goalPace,
      dailyGoalAdjustmentKcal: 0,
      goalFoodTargetKcal: null,
      usedHealthActiveEnergyForTarget: false,
      healthActiveEnergyKcal: null,
      productDefaultsUsed: const [],
      calculatedAt: DateTime.now(),
    );
  }
}
