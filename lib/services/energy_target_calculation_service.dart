import '../data/lifestyle_activity_catalog.dart';
import '../models/activity_level.dart';
import '../models/calculation/calculation_versions.dart';
import '../models/calculation/energy_target_breakdown.dart';
import '../models/calculation/goal_pace.dart';
import '../models/calculation/landing_guidance.dart';
import '../models/calculation/weight_sample.dart';
import '../models/goal.dart';
import '../models/health_snapshot.dart';
import '../models/nutrition_settings.dart';
import '../models/user_profile.dart';
import '../utils/local_date.dart';
import 'daily_calorie_target_planner.dart';
import 'weight_for_target.dart';

/// Mifflin–St Jeor ベースの推定 REE / 維持 / 目標食事カロリー。
class EnergyTargetCalculationService {
  const EnergyTargetCalculationService();

  static const kcalPerKgBodyWeightChange = 7200.0;
  static const minAgeYears = 18;

  static const _planner = DailyCalorieTargetPlanner();

  EnergyTargetBreakdown calculate({
    required UserProfile profile,
    required Goal goal,
    required NutritionSettings settings,
    HealthSnapshot healthSnapshot = HealthSnapshot.empty,
    GoalPace goalPace = GoalPace.standard,
    DateTime? referenceDate,
    List<WeightSample> weightSamples = const [],
    double? autoFoodTargetKcal,
    DateTime? autoFoodTargetOn,
    double? autoFoodTargetPriorKcal,
  }) {
    final now = referenceDate ?? DateTime.now();
    final age = _calculateAge(profile.birthDate, referenceDate: now);
    final series = describeWeightSeries(
      samples: weightSamples,
      reference: now,
      fallbackKg: profile.weightKg,
    );
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

    final currentWeightKg = series.selection.kg > 0
        ? series.selection.kg
        : profile.weightKg;
    if (profile.heightCm <= 0 || currentWeightKg <= 0) {
      return EnergyTargetBreakdown.unavailable(
        reason: '身長・体重が不足しているため、推定値を計算できません。',
        goalType: goal.type,
        goalPace: goalPace,
      );
    }

    final clamp = resolveAutoTargetClamp(
      referenceDate: now,
      autoFoodTargetKcal: autoFoodTargetKcal,
      autoFoodTargetOn: autoFoodTargetOn,
      autoFoodTargetPriorKcal: autoFoodTargetPriorKcal,
    );
    final activityLevel = settings.activityLevel ?? ActivityLevel.moderate;
    final lifestyle = LifestyleActivityCatalog.forLevel(activityLevel);
    productDefaults.add(
      '生活活動係数 ${lifestyle.factor}（${lifestyle.referenceNote}）',
    );

    // 食事目標の土台は REE × 生活活動係数。Health の active energy は足さない。
    final healthActive = healthSnapshot.activeEnergyBurnedKcal;

    if (series.useLandingFormula && series.smoothedKg != null) {
      final smoothed = series.smoothedKg!;
      final ree = _estimateRee(
        profile: profile.copyWith(weightKg: smoothed),
        ageYears: age,
      );
      final maintenance = ree * lifestyle.factor;
      productDefaults.add('体重変化補正 $kcalPerKgBodyWeightChange kcal/kg（アプリ既定）');
      final landing = _planner.plan(
        maintenanceKcal: maintenance,
        smoothedWeightKg: smoothed,
        goalWeightKg: goal.targetWeightKg,
        goalType: goal.type,
        remainingDays: _daysUntilGoalDate(goal.targetDate, referenceDate: now),
        gender: profile.gender,
        referenceDate: now,
        weightStale: series.selection.stale,
        clampBaseKcal: clamp.clampBaseKcal,
        clampDays: clamp.clampDays,
      );
      return _breakdown(
        profile: profile,
        age: age,
        weightKg: smoothed,
        goal: goal,
        goalPace: goalPace,
        activityLevel: activityLevel,
        lifestyleLabel: lifestyle.everydayLabel,
        lifestyleFactor: lifestyle.factor,
        ree: ree,
        maintenance: maintenance,
        adjustmentKcal: landing.appliedBalanceKcal.abs(),
        goalFoodTarget: landing.foodTargetKcal,
        healthActive: healthActive,
        productDefaults: productDefaults,
        now: now,
        series: series,
        rawBalanceKcal: landing.rawBalanceKcal,
        speedCapKcal: landing.speedCapKcal,
        floorKcal: landing.floorKcal,
        smoothedWeightKg: smoothed,
        heldForStaleWeight: landing.heldForStaleWeight,
        dailyStepLimited: landing.dailyStepLimited,
        guidance: landing.guidance,
        anchorUpdate: AutoTargetAnchor(
          targetKcal: landing.foodTargetKcal,
          targetOn: localDayStart(now),
          priorKcal: clamp.priorToStore,
        ),
        usesLandingFormula: true,
      );
    }

    final ree = _estimateRee(
      profile: profile.copyWith(weightKg: currentWeightKg),
      ageYears: age,
    );
    final maintenance = ree * lifestyle.factor;
    final baseAdjustment = _rawDailyAdjustment(
      goal: goal,
      currentWeightKg: currentWeightKg,
      referenceDate: now,
    );
    if (baseAdjustment > 0 && goal.type != GoalType.maintain) {
      productDefaults.add('体重変化補正 $kcalPerKgBodyWeightChange kcal/kg（アプリ既定）');
    }
    final pacedAdjustment = goal.type == GoalType.maintain
        ? 0.0
        : baseAdjustment;

    var goalFoodTarget = _applyGoalType(
      goalType: goal.type,
      maintenanceKcal: maintenance,
      dailyAdjustment: pacedAdjustment,
      targetDate: goal.targetDate,
      referenceDate: now,
    );
    var held = false;
    if (series.selection.stale && clamp.clampBaseKcal != null) {
      goalFoodTarget = clamp.clampBaseKcal!;
      held = true;
    }

    return _breakdown(
      profile: profile,
      age: age,
      weightKg: currentWeightKg,
      goal: goal,
      goalPace: goalPace,
      activityLevel: activityLevel,
      lifestyleLabel: lifestyle.everydayLabel,
      lifestyleFactor: lifestyle.factor,
      ree: ree,
      maintenance: maintenance,
      adjustmentKcal: pacedAdjustment,
      goalFoodTarget: goalFoodTarget,
      healthActive: healthActive,
      productDefaults: productDefaults,
      now: now,
      series: series,
      heldForStaleWeight: held,
      anchorUpdate: AutoTargetAnchor(
        targetKcal: goalFoodTarget,
        targetOn: localDayStart(now),
        priorKcal: clamp.priorToStore,
      ),
      usesLandingFormula: false,
    );
  }

  EnergyTargetBreakdown _breakdown({
    required UserProfile profile,
    required int age,
    required double weightKg,
    required Goal goal,
    required GoalPace goalPace,
    required ActivityLevel activityLevel,
    required String lifestyleLabel,
    required double lifestyleFactor,
    required double ree,
    required double maintenance,
    required double adjustmentKcal,
    required double goalFoodTarget,
    required double? healthActive,
    required List<String> productDefaults,
    required DateTime now,
    required WeightSeries series,
    required AutoTargetAnchor anchorUpdate,
    required bool usesLandingFormula,
    double? rawBalanceKcal,
    double? speedCapKcal,
    double? floorKcal,
    double? smoothedWeightKg,
    bool heldForStaleWeight = false,
    bool dailyStepLimited = false,
    LandingGuidance? guidance,
  }) {
    return EnergyTargetBreakdown(
      version: CalculationVersions.energy,
      ageYears: age,
      heightCm: profile.heightCm,
      weightKg: weightKg,
      genderLabel: profile.gender.label,
      canEstimateRee: true,
      unavailableReason: null,
      estimatedReeKcal: ree,
      lifestyleActivityLevel: activityLevel,
      lifestyleActivityLabel: lifestyleLabel,
      lifestyleActivityFactor: lifestyleFactor,
      estimatedMaintenanceKcal: maintenance,
      goalType: goal.type,
      goalPace: goalPace,
      dailyGoalAdjustmentKcal: adjustmentKcal,
      goalFoodTargetKcal: goalFoodTarget,
      usedHealthActiveEnergyForTarget: false,
      healthActiveEnergyKcal: healthActive,
      productDefaultsUsed: productDefaults,
      calculatedAt: now,
      weightSeries: series,
      rawBalanceKcal: rawBalanceKcal,
      speedCapKcal: speedCapKcal,
      floorKcal: floorKcal,
      smoothedWeightKg: smoothedWeightKg,
      heldForStaleWeight: heldForStaleWeight,
      dailyStepLimited: dailyStepLimited,
      guidance: guidance,
      anchorUpdate: anchorUpdate,
      usesLandingFormula: usesLandingFormula,
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
