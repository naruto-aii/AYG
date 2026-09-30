import 'dart:math' as math;

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
    // 目標体重と目標日が決まっていれば収支は1本。保存済みのペースは使わない。
    final appliedBalance = _applyFloor(
      balance: raw.clamp(-lossCap, gainCap),
      maintenanceKcal: maintenanceKcal,
      floorKcal: _floorKcal(gender),
    );
    final floor = _floorKcal(gender);
    var target = maintenanceKcal + appliedBalance;
    final beforeStep = target;

    final guidance = arrivalGuidance(
      currentWeightKg: smoothedWeightKg,
      goalWeightKg: goalWeightKg,
      goalType: goalType,
      remainingDays: remainingDays,
      referenceDate: referenceDate,
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
      speedCapKcal: raw < 0 ? lossCap : gainCap,
      appliedBalanceKcal: appliedBalance,
      floorKcal: floor,
      foodTargetKcal: target,
      beforeDailyStepKcal: beforeStep,
      heldForStaleWeight: held,
      dailyStepLimited: stepped,
      guidance: held ? null : guidance,
    );
  }

  /// 目標設定の画面用。直線が上限を超えるときだけ短い文を返す。
  String? arrivalNote({
    required double currentWeightKg,
    required double goalWeightKg,
    required GoalType goalType,
    required DateTime targetDate,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final remaining = localDayStart(
      targetDate,
    ).difference(localDayStart(now)).inDays;
    return arrivalGuidance(
      currentWeightKg: currentWeightKg,
      goalWeightKg: goalWeightKg,
      goalType: goalType,
      remainingDays: remaining,
      referenceDate: now,
    )?.message;
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

  /// 直線の速度が安全な上限を超えるときだけ、届かないことと届く日を返す。
  LandingGuidance? arrivalGuidance({
    required double currentWeightKg,
    required double goalWeightKg,
    required GoalType goalType,
    required int remainingDays,
    required DateTime referenceDate,
  }) {
    final kcalPerKg = EnergyTargetCalculationService.kcalPerKgBodyWeightChange;
    final raw = _rawBalance(
      goalType: goalType,
      goalWeightKg: goalWeightKg,
      smoothedWeightKg: currentWeightKg,
      remainingDays: remainingDays,
      kcalPerKg: kcalPerKg,
    );
    if (raw.abs() < 0.5 || remainingDays <= 0) {
      return null;
    }
    final lossCap = _lossCapKcal(currentWeightKg, kcalPerKg);
    final gainCap = _gainCapKcal(currentWeightKg, kcalPerKg);
    final capped = raw.clamp(-lossCap, gainCap);
    if (!_misses(raw: raw, achieved: capped)) {
      return null;
    }

    final rateKgPerDay = capped.abs() / kcalPerKg;
    final gapKg = (goalWeightKg - currentWeightKg).abs();
    final sign = raw < 0 ? -1.0 : 1.0;
    final today = localDayStart(referenceDate);
    DateTime? suggestedDate;
    double? suggestedWeight;
    if (rateKgPerDay > 0.000001) {
      suggestedDate = today.add(Duration(days: (gapKg / rateKgPerDay).ceil()));
      suggestedWeight = currentWeightKg + sign * rateKgPerDay * remainingDays;
    } else {
      suggestedWeight = currentWeightKg;
    }
    final recommended = _smallerChange(
      remainingDays: remainingDays,
      suggestedDate: suggestedDate,
      today: today,
      suggestedWeight: suggestedWeight,
      goalWeightKg: goalWeightKg,
      gapKg: gapKg,
    );
    final date = suggestedDate == null
        ? ''
        : '${suggestedDate.year}年${suggestedDate.month}月${suggestedDate.day}日';
    return LandingGuidance(
      kind: LandingGuidanceKind.exceedsSafeSpeed,
      recommended: recommended,
      alternative: recommended == LandingGuidanceAction.extendDate
          ? LandingGuidanceAction.changeWeight
          : LandingGuidanceAction.extendDate,
      suggestedDate: suggestedDate,
      suggestedWeightKg: suggestedWeight,
      message: date.isEmpty
          ? 'この目標日には届きません。目標日と目標体重は自動では変えません。'
          : 'この目標日には届きません。安全な速度なら$dateに届きます。',
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
