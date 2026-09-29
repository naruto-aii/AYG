import '../data/lifestyle_activity_catalog.dart';
import '../models/activity_level.dart';
import '../models/calculation/calculation_versions.dart';
import '../models/calculation/energy_target_breakdown.dart';
import '../models/calculation/goal_pace.dart';
import '../models/goal.dart';
import '../models/health_snapshot.dart';
import '../models/nutrition_settings.dart';
import '../models/user_profile.dart';

/// Mifflin–St Jeor ベースの推定 REE / 維持 / 目標食事カロリー。
class EnergyTargetCalculationService {
  const EnergyTargetCalculationService();

  static const kcalPerKgBodyWeightChange = 7200.0;
  static const minAgeYears = 18;

  EnergyTargetBreakdown calculate({
    required UserProfile profile,
    required Goal goal,
    required NutritionSettings settings,
    HealthSnapshot healthSnapshot = HealthSnapshot.empty,
    GoalPace goalPace = GoalPace.standard,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final age = _calculateAge(profile.birthDate, referenceDate: now);
    final productDefaults = <String>[];

    if (age < minAgeYears) {
      return EnergyTargetBreakdown.unavailable(
        reason: '18歳未満の方は自動目標設定の対象外です。専門家にご相談ください。',
        goalType: goal.type,
        goalPace: goalPace,
      );
    }

    if (profile.gender == Gender.other) {
      return EnergyTargetBreakdown.unavailable(
        reason:
            '性別が「その他」の場合、推定安静時消費カロリーを自動計算しません。'
            '男性または女性を選択するか、専門家にご相談ください。',
        goalType: goal.type,
        goalPace: goalPace,
      );
    }

    if (profile.heightCm <= 0 || profile.weightKg <= 0) {
      return EnergyTargetBreakdown.unavailable(
        reason: '身長・体重が不足しているため、推定値を計算できません。',
        goalType: goal.type,
        goalPace: goalPace,
      );
    }

    final ree = _estimateRee(profile: profile, ageYears: age);
    final activityLevel = settings.activityLevel ?? ActivityLevel.moderate;
    final lifestyle = LifestyleActivityCatalog.forLevel(activityLevel);
    productDefaults.add(
      '生活活動係数 ${lifestyle.factor}（${lifestyle.referenceNote}）',
    );

    // 食事目標は REE × 生活活動係数のみ。Health の active energy は二重計上防止のため加算しない。
    final maintenance = ree * lifestyle.factor;
    final healthActive = healthSnapshot.activeEnergyBurnedKcal;

    final baseAdjustment = _rawDailyAdjustment(
      goal: goal,
      currentWeightKg: profile.weightKg,
      referenceDate: now,
    );
    if (baseAdjustment > 0 && goal.type != GoalType.maintain) {
      productDefaults.add('体重変化補正 $kcalPerKgBodyWeightChange kcal/kg（アプリ既定）');
    }
    final pacedAdjustment = goal.type == GoalType.maintain
        ? 0.0
        : baseAdjustment * goalPace.adjustmentMultiplier;
    if (goalPace != GoalPace.standard && goal.type != GoalType.maintain) {
      productDefaults.add('目標ペース係数 ${goalPace.adjustmentMultiplier}（アプリ既定）');
    }

    final goalFoodTarget = _applyGoalType(
      goalType: goal.type,
      maintenanceKcal: maintenance,
      dailyAdjustment: pacedAdjustment,
      targetDate: goal.targetDate,
      referenceDate: now,
    );

    return EnergyTargetBreakdown(
      version: CalculationVersions.energy,
      ageYears: age,
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
      genderLabel: profile.gender.label,
      canEstimateRee: true,
      unavailableReason: null,
      estimatedReeKcal: ree,
      lifestyleActivityLevel: activityLevel,
      lifestyleActivityLabel: lifestyle.everydayLabel,
      lifestyleActivityFactor: lifestyle.factor,
      estimatedMaintenanceKcal: maintenance,
      goalType: goal.type,
      goalPace: goalPace,
      dailyGoalAdjustmentKcal: pacedAdjustment,
      goalFoodTargetKcal: goalFoodTarget,
      usedHealthActiveEnergyForTarget: false,
      healthActiveEnergyKcal: healthActive,
      productDefaultsUsed: productDefaults,
      calculatedAt: now,
    );
  }

  double _estimateRee({required UserProfile profile, required int ageYears}) {
    final base =
        (10 * profile.weightKg) + (6.25 * profile.heightCm) - (5 * ageYears);
    return switch (profile.gender) {
      Gender.female => base - 161,
      Gender.male => base + 5,
      Gender.other => throw StateError('REE requires binary gender selection'),
    };
  }

  double _rawDailyAdjustment({
    required Goal goal,
    required double currentWeightKg,
    required DateTime referenceDate,
  }) {
    final days = _daysUntilGoalDate(
      goal.targetDate,
      referenceDate: referenceDate,
    );
    if (days <= 0) {
      return 0;
    }
    final weightDiffKg = (goal.targetWeightKg - currentWeightKg).abs();
    return weightDiffKg * kcalPerKgBodyWeightChange / days;
  }

  double _applyGoalType({
    required GoalType goalType,
    required double maintenanceKcal,
    required double dailyAdjustment,
    required DateTime targetDate,
    required DateTime referenceDate,
  }) {
    if (_daysUntilGoalDate(targetDate, referenceDate: referenceDate) <= 0) {
      return maintenanceKcal;
    }
    return switch (goalType) {
      GoalType.lose => maintenanceKcal - dailyAdjustment,
      GoalType.gain => maintenanceKcal + dailyAdjustment,
      GoalType.maintain => maintenanceKcal,
    };
  }

  int _calculateAge(DateTime birthDate, {required DateTime referenceDate}) {
    final today = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  int _daysUntilGoalDate(
    DateTime targetDate, {
    required DateTime referenceDate,
  }) {
    final today = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return target.difference(today).inDays;
  }
}
