import '../../models/activity_level.dart';
import '../../models/goal.dart';
import 'weight_selection.dart';
import 'calculation_versions.dart';
import 'goal_pace.dart';
import 'landing_guidance.dart';

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
    this.weightSeries,
    this.rawBalanceKcal,
    this.speedCapKcal,
    this.floorKcal,
    this.smoothedWeightKg,
    this.heldForStaleWeight = false,
    this.dailyStepLimited = false,
    this.guidance,
    this.anchorUpdate,
    this.manualTargetsActive = false,
    this.usesLandingFormula = false,
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
  final WeightSeries? weightSeries;
  final double? rawBalanceKcal;
  final double? speedCapKcal;
  final double? floorKcal;
  final double? smoothedWeightKg;
  final bool heldForStaleWeight;
  final bool dailyStepLimited;
  final LandingGuidance? guidance;
  final AutoTargetAnchor? anchorUpdate;
  final bool manualTargetsActive;
  final bool usesLandingFormula;

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
