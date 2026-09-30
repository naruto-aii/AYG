import 'dart:math' as math;

import '../models/calculation/goal_pace.dart';
import '../models/calculation/landing_guidance.dart';
import '../models/goal.dart';
import '../models/user_profile.dart';
import '../utils/local_date.dart';
import 'energy_target_calculation_service.dart';

/// 着地式に掛ける制限。初期式（記録不足）には掛けない。
class DailyCalorieTargetPlanner {
  const DailyCalorieTargetPlanner();

  static const dailyStepKcal = 150.0;
  static const femaleFloorKcal = 1200.0;
  static const maleFloorKcal = 1500.0;

  LandingPlan plan({
    required double maintenanceKcal,
    required double smoothedWeightKg,
    required double goalWeightKg,
    required GoalType goalType,
    required GoalPace goalPace,
    required int remainingDays,
    required Gender gender,
    required DateTime referenceDate,
    required bool weightStale,
    required double? clampBaseKcal,
    required int clampDays,
  }) {
    final kcalPerKg = EnergyTargetCalculationService.kcalPerKgBodyWeightChange;
    final raw = _rawBalance(
      goalType: goalType,
      goalWeightKg: goalWeightKg,
      smoothedWeightKg: smoothedWeightKg,
      remainingDays: remainingDays,
      kcalPerKg: kcalPerKg,
    );
    final lossCap = _lossCapKcal(smoothedWeightKg, kcalPerKg);
    final gainCap = _gainCapKcal(smoothedWeightKg, kcalPerKg);
    final pace = goalPace == GoalPace.slow
        ? goalPace.adjustmentMultiplier
        : 1.0;
    final floor = _floorKcal(gender);

    final atStandard = _applyFloor(
      balance: raw.clamp(-lossCap, gainCap),
      maintenanceKcal: maintenanceKcal,
      floorKcal: floor,
    );
    final atPace = _applyFloor(
      balance: raw.clamp(-lossCap * pace, gainCap * pace),
      maintenanceKcal: maintenanceKcal,
      floorKcal: floor,
    );
    final appliedBalance = goalPace == GoalPace.slow ? atPace : atStandard;
    var target = maintenanceKcal + appliedBalance;
    final beforeStep = target;

    final guidance = _guidance(
      raw: raw,
      atStandard: atStandard,
      atPace: atPace,
      goalPace: goalPace,
      smoothedWeightKg: smoothedWeightKg,
      goalWeightKg: goalWeightKg,
      remainingDays: remainingDays,
      referenceDate: referenceDate,
      kcalPerKg: kcalPerKg,
      maintenanceKcal: maintenanceKcal,
    );

    var held = false;
    var stepped = false;
    if (weightStale && clampBaseKcal != null) {
      target = clampBaseKcal;
      held = true;
    } else if (clampBaseKcal != null && clampDays > 0) {
      final allowance = dailyStepKcal * clampDays;
      final steppedTarget = target.clamp(
        clampBaseKcal - allowance,
        clampBaseKcal + allowance,
      );
      stepped = (steppedTarget - target).abs() > 0.01;
      target = steppedTarget;
    }

    return LandingPlan(
      rawBalanceKcal: raw,
      speedCapKcal: (raw < 0 ? lossCap : gainCap) * pace,
      appliedBalanceKcal: appliedBalance,
      floorKcal: floor,
      foodTargetKcal: target,
      beforeDailyStepKcal: beforeStep,
      heldForStaleWeight: held,
      dailyStepLimited: stepped,
      guidance: held ? null : guidance,
    );
  }

  /// 減量は週1kgと現体重の週1%の小さい方。週1kgは 7,200÷7 ≒ 1,029 kcal/日。
  double lossCapKcalPerDay(double weightKg) => _lossCapKcal(
    weightKg,
    EnergyTargetCalculationService.kcalPerKgBodyWeightChange,
  );

  double gainCapKcalPerDay(double weightKg) => _gainCapKcal(
    weightKg,
    EnergyTargetCalculationService.kcalPerKgBodyWeightChange,
  );

  double _lossCapKcal(double weightKg, double kcalPerKg) {
    final weeklyKg = math.min(1.0, weightKg * 0.01);
    return weeklyKg * kcalPerKg / 7;
  }

  double _gainCapKcal(double weightKg, double kcalPerKg) {
    return weightKg * 0.005 * kcalPerKg / 7;
  }

  double _rawBalance({
    required GoalType goalType,
    required double goalWeightKg,
    required double smoothedWeightKg,
    required int remainingDays,
    required double kcalPerKg,
  }) {
    if (goalType == GoalType.maintain || remainingDays <= 0) {
      return 0;
    }
    return (goalWeightKg - smoothedWeightKg) * kcalPerKg / remainingDays;
  }

  double? _floorKcal(Gender gender) {
    return switch (gender) {
      Gender.female => femaleFloorKcal,
      Gender.male => maleFloorKcal,
      Gender.other => null,
    };
  }

  double _applyFloor({
    required double balance,
    required double maintenanceKcal,
    required double? floorKcal,
  }) {
    if (floorKcal == null) {
      return balance;
    }
    final target = maintenanceKcal + balance;
    if (target < floorKcal) {
      return floorKcal - maintenanceKcal;
    }
    return balance;
  }

  LandingGuidance? _guidance({
    required double raw,
    required double atStandard,
    required double atPace,
    required GoalPace goalPace,
    required double smoothedWeightKg,
    required double goalWeightKg,
    required int remainingDays,
    required DateTime referenceDate,
    required double kcalPerKg,
    required double maintenanceKcal,
  }) {
    if (raw.abs() < 0.5 || remainingDays <= 0) {
      return null;
    }
    final missesStandard = _misses(raw: raw, achieved: atStandard);
    final missesPace = _misses(raw: raw, achieved: atPace);
    if (!missesStandard && !(goalPace == GoalPace.slow && missesPace)) {
      return null;
    }

    final exceedsSafe = missesStandard;
    final rateBalance = exceedsSafe ? atStandard : atPace;
    final rateKgPerDay = rateBalance.abs() / kcalPerKg;
    final gapKg = (goalWeightKg - smoothedWeightKg).abs();
    final sign = raw < 0 ? -1.0 : 1.0;
    final today = localDayStart(referenceDate);

    DateTime? suggestedDate;
    double? suggestedWeight;
    if (rateKgPerDay > 0.000001) {
      final daysNeeded = (gapKg / rateKgPerDay).ceil();
      suggestedDate = today.add(Duration(days: daysNeeded));
      final reachableDelta = rateKgPerDay * remainingDays;
      suggestedWeight = smoothedWeightKg + sign * reachableDelta;
    } else {
      suggestedWeight = smoothedWeightKg;
    }

    if (exceedsSafe) {
      final recommended = _smallerChange(
        remainingDays: remainingDays,
        suggestedDate: suggestedDate,
        today: today,
        suggestedWeight: suggestedWeight,
        goalWeightKg: goalWeightKg,
        gapKg: gapKg,
      );
      final alternative = recommended == LandingGuidanceAction.extendDate
          ? LandingGuidanceAction.changeWeight
          : LandingGuidanceAction.extendDate;
      return LandingGuidance(
        kind: LandingGuidanceKind.exceedsSafeSpeed,
        recommended: recommended,
        alternative: alternative,
        suggestedDate: suggestedDate,
        suggestedWeightKg: suggestedWeight,
        message:
            '安全な速度では目標日に届きません。食事目標は安全な範囲のままにします。'
            '目標日と目標体重は自動では変えません。',
      );
    }

    return LandingGuidance(
      kind: LandingGuidanceKind.slowPaceCannotReach,
      recommended: LandingGuidanceAction.extendDate,
      alternative: LandingGuidanceAction.useStandardPace,
      suggestedDate: suggestedDate,
      suggestedWeightKg: suggestedWeight,
      message:
          '「ゆっくり」の範囲では目標日に届きません。食事目標はゆっくりの上限のままにします。'
          '目標日と目標体重は自動では変えません。',
    );
  }

  bool _misses({required double raw, required double achieved}) {
    if (raw < -0.5) {
      return achieved > raw + 0.5;
    }
    if (raw > 0.5) {
      return achieved < raw - 0.5;
    }
    return false;
  }

  LandingGuidanceAction _smallerChange({
    required int remainingDays,
    required DateTime? suggestedDate,
    required DateTime today,
    required double? suggestedWeight,
    required double goalWeightKg,
    required double gapKg,
  }) {
    if (suggestedDate == null) {
      return LandingGuidanceAction.changeWeight;
    }
    if (suggestedWeight == null) {
      return LandingGuidanceAction.extendDate;
    }
    final extraDays = suggestedDate.difference(today).inDays - remainingDays;
    final dateRatio = extraDays / math.max(remainingDays, 1);
    final weightRatio =
        (suggestedWeight - goalWeightKg).abs() / math.max(gapKg, 0.1);
    if (dateRatio <= weightRatio) {
      return LandingGuidanceAction.extendDate;
    }
    return LandingGuidanceAction.changeWeight;
  }
}

class LandingPlan {
  const LandingPlan({
    required this.rawBalanceKcal,
    required this.speedCapKcal,
    required this.appliedBalanceKcal,
    required this.floorKcal,
    required this.foodTargetKcal,
    required this.beforeDailyStepKcal,
    required this.heldForStaleWeight,
    required this.dailyStepLimited,
    required this.guidance,
  });

  /// （目標体重 − 平滑体重）× 7,200 ÷ 残日数。維持と期限切れは 0。
  final double rawBalanceKcal;

  /// いまのペースを掛けた、不足または余剰の上限（kcal/日、正の値）。
  final double speedCapKcal;
  final double appliedBalanceKcal;
  final double? floorKcal;
  final double foodTargetKcal;
  final double beforeDailyStepKcal;
  final bool heldForStaleWeight;
  final bool dailyStepLimited;
  final LandingGuidance? guidance;
}

/// 保存済みの自動目標から、今日の ±150 の基準を決める。
({double? clampBaseKcal, int clampDays, double? priorToStore})
resolveAutoTargetClamp({
  required DateTime referenceDate,
  required double? autoFoodTargetKcal,
  required DateTime? autoFoodTargetOn,
  required double? autoFoodTargetPriorKcal,
}) {
  if (autoFoodTargetKcal == null || autoFoodTargetOn == null) {
    return (clampBaseKcal: null, clampDays: 0, priorToStore: null);
  }
  final today = localDayStart(referenceDate);
  final stored = localDayStart(autoFoodTargetOn);
  if (isSameLocalDay(stored, today)) {
    return (
      clampBaseKcal: autoFoodTargetPriorKcal,
      clampDays: autoFoodTargetPriorKcal == null ? 0 : 1,
      priorToStore: autoFoodTargetPriorKcal,
    );
  }
  if (stored.isBefore(today)) {
    final days = today.difference(stored).inDays;
    return (
      clampBaseKcal: autoFoodTargetKcal,
      clampDays: days,
      priorToStore: autoFoodTargetKcal,
    );
  }
  return (clampBaseKcal: null, clampDays: 0, priorToStore: null);
}
