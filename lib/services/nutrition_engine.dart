import '../models/activity_level.dart';
import '../models/alcohol_entry.dart';
import '../models/calculation/energy_target_breakdown.dart';
import '../models/calculation/goal_pace.dart';
import '../models/daily_summary.dart';
import '../models/exercise_entry.dart';
import '../models/food_entry.dart';
import '../models/goal.dart';
import '../models/health_snapshot.dart';
import '../models/nutrition_settings.dart';
import '../models/target_macros.dart';
import '../models/user_profile.dart';
import '../utils/local_date.dart';
import 'energy_target_calculation_service.dart';
import 'macro_target_calculation_service.dart';
import 'remaining_calorie_service.dart';

/// Science-based Nutrition Engine（energy_v2 / macro_v2）。
class NutritionEngine {
  static const _remainingCalorieService = RemainingCalorieService();
  static const _energyService = EnergyTargetCalculationService();
  static const _macroService = MacroTargetCalculationService();

  static const double kcalPerKgBodyWeightChange =
      EnergyTargetCalculationService.kcalPerKgBodyWeightChange;

  DailySummary calculateDailySummary({
    required UserProfile profile,
    required Goal goal,
    required NutritionSettings settings,
    required List<FoodEntry> foodEntries,
    required List<ExerciseEntry> exerciseEntries,
    List<AlcoholEntry> alcoholEntries = const [],
    HealthSnapshot healthSnapshot = HealthSnapshot.empty,
    GoalPace goalPace = GoalPace.standard,
    DateTime? referenceDate,
  }) {
    final selectedDay = referenceDate ?? DateTime.now();
    final energy = _energyService.calculate(
      profile: profile,
      goal: goal,
      settings: settings,
      healthSnapshot: healthSnapshot,
      goalPace: goalPace,
      referenceDate: selectedDay,
    );

    if (!energy.canEstimateRee || energy.goalFoodTargetKcal == null) {
      return _emptySummary(
        energy: energy,
        foodEntries: foodEntries,
        alcoholEntries: alcoholEntries,
        exerciseEntries: exerciseEntries,
        selectedDay: selectedDay,
      );
    }

    final targetKcal = energy.goalFoodTargetKcal!;
    final hasStrength = _macroService.inferStrengthTrainingHabit(
      recentCategories: exerciseEntries
          .map((entry) => entry.category)
          .take(30)
          .toList(),
    );
    final macroBreakdown = _macroService.calculate(
      goalType: goal.type,
      goalFoodTargetKcal: targetKcal,
      referenceWeightKg: profile.weightKg,
      hasStrengthTrainingHabit: hasStrength,
    );

    final dayFoodEntries = filterLoggedOnLocalDay(
      entries: foodEntries,
      referenceDate: selectedDay,
      readLoggedAt: (entry) => entry.loggedAt,
    );

    final remainingBreakdown = _remainingCalorieService.calculateBreakdown(
      baseDailyFoodTargetKcal: targetKcal,
      foodEntries: foodEntries,
      alcoholEntries: alcoholEntries,
      exerciseEntries: exerciseEntries,
      selectedDay: selectedDay,
    );

    return DailySummary(
      targetKcal: targetKcal,
      remainingKcal: remainingBreakdown.rawRemainingKcal,
      targetProteinG: macroBreakdown.proteinG,
      targetFatG: macroBreakdown.fatG,
      targetCarbG: macroBreakdown.carbG,
      intakeKcal: remainingBreakdown.intakeKcal,
      intakeProteinG: _sumFoodProtein(dayFoodEntries),
      intakeFatG: _sumFoodFat(dayFoodEntries),
      intakeCarbG: _sumFoodCarb(dayFoodEntries),
      exerciseBurnKcal: remainingBreakdown.exerciseNetKcal,
      isCalorieOverage: remainingBreakdown.isOverage,
      calorieOverageKcal: remainingBreakdown.overageKcal,
      energyBreakdown: energy,
      macroBreakdown: macroBreakdown,
      remainingBreakdown: remainingBreakdown,
    );
  }

  DailySummary _emptySummary({
    required EnergyTargetBreakdown energy,
    required List<FoodEntry> foodEntries,
    required List<AlcoholEntry> alcoholEntries,
    required List<ExerciseEntry> exerciseEntries,
    required DateTime selectedDay,
  }) {
    final remainingBreakdown = _remainingCalorieService.calculateBreakdown(
      baseDailyFoodTargetKcal: 0,
      foodEntries: foodEntries,
      alcoholEntries: alcoholEntries,
      exerciseEntries: exerciseEntries,
      selectedDay: selectedDay,
    );
    return DailySummary(
      targetKcal: 0,
      remainingKcal: remainingBreakdown.rawRemainingKcal,
      targetProteinG: 0,
      targetFatG: 0,
      targetCarbG: 0,
      intakeKcal: remainingBreakdown.intakeKcal,
      intakeProteinG: 0,
      intakeFatG: 0,
      intakeCarbG: 0,
      exerciseBurnKcal: remainingBreakdown.exerciseNetKcal,
      isCalorieOverage: remainingBreakdown.isOverage,
      calorieOverageKcal: remainingBreakdown.overageKcal,
      energyBreakdown: energy,
      remainingBreakdown: remainingBreakdown,
    );
  }

  // --- 後方互換（テスト・既存呼び出し） ---

  int calculateAge(DateTime birthDate, {DateTime? referenceDate}) {
    final today = _dateOnly(referenceDate ?? DateTime.now());
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  double calculateBMR({required UserProfile profile, DateTime? referenceDate}) {
    final age = calculateAge(profile.birthDate, referenceDate: referenceDate);
    final base =
        (10 * profile.weightKg) + (6.25 * profile.heightCm) - (5 * age);
    return switch (profile.gender) {
      Gender.female => base - 161,
      Gender.male || Gender.other => base + 5,
    };
  }

  double calculateTDEEFromActivityFactor({
    required double bmr,
    required ActivityLevel activityLevel,
  }) => bmr * activityLevel.factor;

  double calculateTDEEFromHealth({
    required double bmr,
    required double activeEnergyBurnedKcal,
  }) => bmr + activeEnergyBurnedKcal;

  int daysUntilGoalDate(DateTime targetDate, {DateTime? referenceDate}) {
    final today = _dateOnly(referenceDate ?? DateTime.now());
    final target = _dateOnly(targetDate);
    return target.difference(today).inDays;
  }

  double calculateDailyAdjustment({
    required Goal goal,
    required double currentWeightKg,
    DateTime? referenceDate,
  }) {
    final days = daysUntilGoalDate(
      goal.targetDate,
      referenceDate: referenceDate,
    );
    if (days <= 0) {
      return 0;
    }
    final weightDiffKg = (goal.targetWeightKg - currentWeightKg).abs();
    return weightDiffKg * kcalPerKgBodyWeightChange / days;
  }

  double calculateTargetCalories({
    required GoalType goalType,
    required double tdee,
    required double dailyAdjustment,
    required DateTime targetDate,
    DateTime? referenceDate,
  }) {
    if (daysUntilGoalDate(targetDate, referenceDate: referenceDate) <= 0) {
      return tdee;
    }
    return switch (goalType) {
      GoalType.lose => tdee - dailyAdjustment,
      GoalType.gain => tdee + dailyAdjustment,
      GoalType.maintain => tdee,
    };
  }

  TargetMacros calculateTargetMacros({
    required GoalType goalType,
    required double targetCalories,
    required double weightKg,
    bool hasStrengthTrainingHabit = false,
  }) {
    final breakdown = _macroService.calculate(
      goalType: goalType,
      goalFoodTargetKcal: targetCalories,
      referenceWeightKg: weightKg,
      hasStrengthTrainingHabit: hasStrengthTrainingHabit,
    );
    return TargetMacros(
      proteinG: breakdown.proteinG,
      fatG: breakdown.fatG,
      carbG: breakdown.carbG,
    );
  }

  double calculateRemainingCalories({
    required double targetCalories,
    required double foodCalories,
    required double exerciseCalories,
  }) => targetCalories - foodCalories + exerciseCalories;

  double resolveTdee({
    required double bmr,
    required NutritionSettings settings,
    HealthSnapshot healthSnapshot = HealthSnapshot.empty,
  }) {
    if (settings.useHealthIntegration) {
      return calculateTDEEFromHealth(
        bmr: bmr,
        activeEnergyBurnedKcal: healthSnapshot.activeEnergyBurnedKcal ?? 0,
      );
    }
    return calculateTDEEFromActivityFactor(
      bmr: bmr,
      activityLevel: settings.activityLevel!,
    );
  }

  double _sumFoodProtein(List<FoodEntry> entries) =>
      entries.fold(0, (sum, entry) => sum + entry.totalProteinG);

  double _sumFoodFat(List<FoodEntry> entries) =>
      entries.fold(0, (sum, entry) => sum + entry.totalFatG);

  double _sumFoodCarb(List<FoodEntry> entries) =>
      entries.fold(0, (sum, entry) => sum + entry.totalCarbG);

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
