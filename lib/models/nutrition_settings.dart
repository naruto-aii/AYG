import 'activity_level.dart';
import 'calculation/calorie_target_mode.dart';

class NutritionSettings {
  const NutritionSettings({
    required this.useHealthIntegration,
    this.activityLevel,
    this.calorieTargetMode = CalorieTargetMode.automatic,
    this.manualTargetKcal,
    this.manualProteinG,
    this.manualFatG,
    this.manualCarbG,
    this.autoFoodTargetKcal,
    this.autoFoodTargetOn,
    this.autoFoodTargetPriorKcal,
  }) : assert(
         useHealthIntegration || activityLevel != null,
         'Activity level is required when health integration is disabled.',
       );

  final bool useHealthIntegration;
  final ActivityLevel? activityLevel;
  final CalorieTargetMode calorieTargetMode;
  final double? manualTargetKcal;
  final double? manualProteinG;
  final double? manualFatG;
  final double? manualCarbG;

  /// 直近に自動計算した食事目標。前日比 ±150 kcal の基準。
  final double? autoFoodTargetKcal;
  final DateTime? autoFoodTargetOn;
  final double? autoFoodTargetPriorKcal;

  bool get usesManualTargets =>
      calorieTargetMode == CalorieTargetMode.manual &&
      manualTargetKcal != null &&
      manualTargetKcal! > 0 &&
      manualProteinG != null &&
      manualFatG != null &&
      manualCarbG != null;

  NutritionSettings copyWith({
    bool? useHealthIntegration,
    ActivityLevel? activityLevel,
    CalorieTargetMode? calorieTargetMode,
    double? manualTargetKcal,
    double? manualProteinG,
    double? manualFatG,
    double? manualCarbG,
    double? autoFoodTargetKcal,
    DateTime? autoFoodTargetOn,
    double? autoFoodTargetPriorKcal,
    bool clearAutoFoodTarget = false,
    bool clearAutoFoodTargetPrior = false,
  }) {
    return NutritionSettings(
      useHealthIntegration: useHealthIntegration ?? this.useHealthIntegration,
      activityLevel: activityLevel ?? this.activityLevel,
      calorieTargetMode: calorieTargetMode ?? this.calorieTargetMode,
      manualTargetKcal: manualTargetKcal ?? this.manualTargetKcal,
      manualProteinG: manualProteinG ?? this.manualProteinG,
      manualFatG: manualFatG ?? this.manualFatG,
      manualCarbG: manualCarbG ?? this.manualCarbG,
      autoFoodTargetKcal: clearAutoFoodTarget
          ? null
          : (autoFoodTargetKcal ?? this.autoFoodTargetKcal),
      autoFoodTargetOn: clearAutoFoodTarget
          ? null
          : (autoFoodTargetOn ?? this.autoFoodTargetOn),
      autoFoodTargetPriorKcal: clearAutoFoodTarget || clearAutoFoodTargetPrior
          ? (clearAutoFoodTarget ? null : autoFoodTargetPriorKcal)
          : (autoFoodTargetPriorKcal ?? this.autoFoodTargetPriorKcal),
    );
  }
}
