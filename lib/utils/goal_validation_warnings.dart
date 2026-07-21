import '../constants/app_strings.dart';
import '../models/goal.dart';

/// 目標設定の矛盾を検出する（警告のみ。保存阻止はしない）。
List<String> collectGoalWarnings({
  required GoalType goalType,
  required double targetWeightKg,
  required double currentWeightKg,
  required DateTime targetDate,
  DateTime? referenceDate,
}) {
  final today = DateTime(
    (referenceDate ?? DateTime.now()).year,
    (referenceDate ?? DateTime.now()).month,
    (referenceDate ?? DateTime.now()).day,
  );
  final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
  final days = target.difference(today).inDays;
  final warnings = <String>[];

  if (goalType == GoalType.lose && targetWeightKg >= currentWeightKg) {
    warnings.add(AppStrings.goalWarningLoseAboveCurrent);
  }
  if (goalType == GoalType.gain && targetWeightKg <= currentWeightKg) {
    warnings.add(AppStrings.goalWarningGainBelowCurrent);
  }
  if (goalType == GoalType.maintain &&
      (targetWeightKg - currentWeightKg).abs() > 0.5) {
    warnings.add(AppStrings.goalWarningMaintainMismatch);
  }
  if (days > 0 && days < 14) {
    warnings.add(AppStrings.goalWarningShortPeriod);
  }

  return warnings;
}
