import '../models/activity_level.dart';
import '../models/daily_summary.dart';
import '../models/exercise_entry.dart';
import '../models/food_entry.dart';
import '../models/goal.dart';
import '../models/health_snapshot.dart';
import '../models/nutrition_settings.dart';
import '../models/target_macros.dart';
import '../models/user_profile.dart';

/// Version 1.1 正式 Nutrition Engine。
class NutritionEngine {
  static const double kcalPerKgBodyWeightChange = 7200;
  static const double proteinKcalPerGram = 4;
  static const double fatKcalPerGram = 9;
  static const double carbKcalPerGram = 4;

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
  }) {
    return bmr * activityLevel.factor;
  }

  double calculateTDEEFromHealth({
    required double bmr,
    required double activeEnergyBurnedKcal,
  }) {
    return bmr + activeEnergyBurnedKcal;
  }

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
    final requiredTotalEnergy = weightDiffKg * kcalPerKgBodyWeightChange;
    return requiredTotalEnergy / days;
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

  double proteinGramsPerKg(GoalType goalType) {
    return switch (goalType) {
      GoalType.lose => 2.0,
      GoalType.maintain => 1.6,
      GoalType.gain => 1.8,
    };
  }

  double fatGramsPerKg() => 0.8;

  TargetMacros calculateTargetMacros({
    required GoalType goalType,
    required double targetCalories,
    required double weightKg,
  }) {
    final proteinG = proteinGramsPerKg(goalType) * weightKg;
    final fatG = fatGramsPerKg() * weightKg;
    final proteinKcal = proteinG * proteinKcalPerGram;
    final fatKcal = fatG * fatKcalPerGram;
    final remainingKcal = targetCalories - proteinKcal - fatKcal;
    final carbG = remainingKcal > 0 ? remainingKcal / carbKcalPerGram : 0.0;

    return TargetMacros(proteinG: proteinG, fatG: fatG, carbG: carbG);
  }

  double calculateRemainingCalories({
    required double targetCalories,
    required double foodCalories,
    required double exerciseCalories,
  }) {
    return targetCalories - foodCalories + exerciseCalories;
  }

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

  DailySummary calculateDailySummary({
    required UserProfile profile,
    required Goal goal,
    required NutritionSettings settings,
    required List<FoodEntry> foodEntries,
    required List<ExerciseEntry> exerciseEntries,
    HealthSnapshot healthSnapshot = HealthSnapshot.empty,
    DateTime? referenceDate,
  }) {
    final bmr = calculateBMR(profile: profile, referenceDate: referenceDate);
    final tdee = resolveTdee(
      bmr: bmr,
      settings: settings,
      healthSnapshot: healthSnapshot,
    );
    final dailyAdjustment = calculateDailyAdjustment(
      goal: goal,
      currentWeightKg: profile.weightKg,
      referenceDate: referenceDate,
    );
    final targetKcal = calculateTargetCalories(
      goalType: goal.type,
      tdee: tdee,
      dailyAdjustment: dailyAdjustment,
      targetDate: goal.targetDate,
      referenceDate: referenceDate,
    );
    final targetMacros = calculateTargetMacros(
      goalType: goal.type,
      targetCalories: targetKcal,
      weightKg: profile.weightKg,
    );

    final intakeKcal = _sumFoodKcal(foodEntries);
    final intakeProteinG = _sumFoodProtein(foodEntries);
    final intakeFatG = _sumFoodFat(foodEntries);
    final intakeCarbG = _sumFoodCarb(foodEntries);
    final exerciseBurnKcal = _sumExerciseBurn(exerciseEntries);
    final remainingKcal = calculateRemainingCalories(
      targetCalories: targetKcal,
      foodCalories: intakeKcal,
      exerciseCalories: exerciseBurnKcal,
    );

    return DailySummary(
      targetKcal: targetKcal,
      remainingKcal: remainingKcal,
      targetProteinG: targetMacros.proteinG,
      targetFatG: targetMacros.fatG,
      targetCarbG: targetMacros.carbG,
      intakeKcal: intakeKcal,
      intakeProteinG: intakeProteinG,
      intakeFatG: intakeFatG,
      intakeCarbG: intakeCarbG,
      exerciseBurnKcal: exerciseBurnKcal,
    );
  }

  double _sumFoodKcal(List<FoodEntry> entries) {
    return entries.fold(0, (sum, entry) => sum + entry.totalKcal);
  }

  double _sumFoodProtein(List<FoodEntry> entries) {
    return entries.fold(0, (sum, entry) => sum + entry.totalProteinG);
  }

  double _sumFoodFat(List<FoodEntry> entries) {
    return entries.fold(0, (sum, entry) => sum + entry.totalFatG);
  }

  double _sumFoodCarb(List<FoodEntry> entries) {
    return entries.fold(0, (sum, entry) => sum + entry.totalCarbG);
  }

  double _sumExerciseBurn(List<ExerciseEntry> entries) {
    return entries.fold(0, (sum, entry) => sum + entry.burnedKcal);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
