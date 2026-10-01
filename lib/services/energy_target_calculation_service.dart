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

  /// この日数より新しい記録だけを、「下げる前の体重」の上限に使う。
  static const lossWeightCeilingLookbackDays = 28;

  static const _weightDropEpsilonKg = 0.05;

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
    bool applyLossCeiling = true,
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
      return _capLossFoodTarget(
        breakdown: _breakdown(
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
        ),
        profile: profile,
        goal: goal,
        settings: settings,
        healthSnapshot: healthSnapshot,
        goalPace: goalPace,
        now: now,
        weightSamples: weightSamples,
        autoFoodTargetKcal: autoFoodTargetKcal,
        autoFoodTargetOn: autoFoodTargetOn,
        autoFoodTargetPriorKcal: autoFoodTargetPriorKcal,
        applyLossCeiling: applyLossCeiling,
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

    return _capLossFoodTarget(
      breakdown: _breakdown(
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
      ),
      profile: profile,
      goal: goal,
      settings: settings,
      healthSnapshot: healthSnapshot,
      goalPace: goalPace,
      now: now,
      weightSamples: weightSamples,
      autoFoodTargetKcal: autoFoodTargetKcal,
      autoFoodTargetOn: autoFoodTargetOn,
      autoFoodTargetPriorKcal: autoFoodTargetPriorKcal,
      applyLossCeiling: applyLossCeiling,
    );
  }

  /// 減量で今の体重が下がったとき、自動目標を上げない。
  ///
  /// 上がる計算なら、保存済みの自動目標を上限にする。保存が無いときは、
  /// 下がる前の体重で出した自動目標を上限にする。速度の上限・食事の床・
  /// ±150 kcal では、このとき目標を上げない。
  /// 目標日が当日で不足が 0 になるときも、減量中は維持カロリーまで上げない。
  EnergyTargetBreakdown _capLossFoodTarget({
    required EnergyTargetBreakdown breakdown,
    required UserProfile profile,
    required Goal goal,
    required NutritionSettings settings,
    required HealthSnapshot healthSnapshot,
    required GoalPace goalPace,
    required DateTime now,
    required List<WeightSample> weightSamples,
    required double? autoFoodTargetKcal,
    required DateTime? autoFoodTargetOn,
    required double? autoFoodTargetPriorKcal,
    required bool applyLossCeiling,
  }) {
    if (!applyLossCeiling) {
      return breakdown;
    }
    final food = breakdown.goalFoodTargetKcal;
    final maintenance = breakdown.estimatedMaintenanceKcal;
    final calcWeight = breakdown.smoothedWeightKg ?? breakdown.weightKg;
    if (goal.type != GoalType.lose ||
        food == null ||
        maintenance == null ||
        calcWeight == null) {
      return breakdown;
    }

    var capped = food;
    final days = _daysUntilGoalDate(goal.targetDate, referenceDate: now);
    if (days <= 0 &&
        autoFoodTargetKcal != null &&
        capped > autoFoodTargetKcal) {
      capped = autoFoodTargetKcal;
    }

    final heavierKg = _recentHeavierKg(
      samples: weightSamples,
      calcWeightKg: calcWeight,
      reference: now,
    );
    if (heavierKg != null && autoFoodTargetKcal != null) {
      if (capped > autoFoodTargetKcal) {
        capped = autoFoodTargetKcal;
      }
    } else if (heavierKg != null) {
      final atHeavier = calculate(
        profile: profile.copyWith(weightKg: heavierKg),
        goal: goal,
        settings: settings,
        healthSnapshot: healthSnapshot,
        goalPace: goalPace,
        referenceDate: now,
        weightSamples: [
          for (final sample in weightSamples)
            WeightSample(
              kg: heavierKg,
              measuredAt: sample.measuredAt,
              source: sample.source,
            ),
        ],
        autoFoodTargetKcal: autoFoodTargetKcal,
        autoFoodTargetOn: autoFoodTargetOn,
        autoFoodTargetPriorKcal: autoFoodTargetPriorKcal,
        applyLossCeiling: false,
      );
      final heavierFood = atHeavier.goalFoodTargetKcal;
      if (heavierFood != null && capped > heavierFood) {
        capped = heavierFood;
      }
    }

    if ((capped - food).abs() < 0.01) {
      return breakdown;
    }

    final prior = breakdown.anchorUpdate?.priorKcal;
    return EnergyTargetBreakdown(
      version: breakdown.version,
      ageYears: breakdown.ageYears,
      heightCm: breakdown.heightCm,
      weightKg: breakdown.weightKg,
      genderLabel: breakdown.genderLabel,
      canEstimateRee: breakdown.canEstimateRee,
      unavailableReason: breakdown.unavailableReason,
      estimatedReeKcal: breakdown.estimatedReeKcal,
      lifestyleActivityLevel: breakdown.lifestyleActivityLevel,
      lifestyleActivityLabel: breakdown.lifestyleActivityLabel,
      lifestyleActivityFactor: breakdown.lifestyleActivityFactor,
      estimatedMaintenanceKcal: breakdown.estimatedMaintenanceKcal,
      goalType: breakdown.goalType,
      goalPace: breakdown.goalPace,
      dailyGoalAdjustmentKcal: (maintenance - capped).abs(),
      goalFoodTargetKcal: capped,
      usedHealthActiveEnergyForTarget:
          breakdown.usedHealthActiveEnergyForTarget,
      healthActiveEnergyKcal: breakdown.healthActiveEnergyKcal,
      productDefaultsUsed: breakdown.productDefaultsUsed,
      calculatedAt: breakdown.calculatedAt,
      weightSeries: breakdown.weightSeries,
      rawBalanceKcal: breakdown.rawBalanceKcal,
      speedCapKcal: breakdown.speedCapKcal,
      floorKcal: breakdown.floorKcal,
      smoothedWeightKg: breakdown.smoothedWeightKg,
      heldForStaleWeight: breakdown.heldForStaleWeight,
      dailyStepLimited: false,
      guidance: breakdown.guidance,
      anchorUpdate: AutoTargetAnchor(
        targetKcal: capped,
        targetOn: localDayStart(now),
        priorKcal: prior,
      ),
      usesLandingFormula: breakdown.usesLandingFormula,
    );
  }

  /// 直近の記録に、計算に使った体重より重いものがあれば、その重い方を返す。
  double? _recentHeavierKg({
    required List<WeightSample> samples,
    required double calcWeightKg,
    required DateTime reference,
  }) {
    final cutoff = reference.subtract(
      const Duration(days: lossWeightCeilingLookbackDays),
    );
    double? heavier;
    for (final sample in samples) {
      if (sample.measuredAt.isBefore(cutoff)) {
        continue;
      }
      if (sample.kg <= calcWeightKg + _weightDropEpsilonKg) {
        continue;
      }
      if (heavier == null || sample.kg > heavier) {
        heavier = sample.kg;
      }
    }
    return heavier;
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
