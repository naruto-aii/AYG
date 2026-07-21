import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/utils/goal_validation_warnings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final referenceDate = DateTime(2026, 7, 21);

  test('collectGoalWarnings warns when lose goal is above current weight', () {
    final warnings = collectGoalWarnings(
      goalType: GoalType.lose,
      targetWeightKg: 80,
      currentWeightKg: 75,
      targetDate: referenceDate.add(const Duration(days: 90)),
      referenceDate: referenceDate,
    );

    expect(warnings, contains(AppStrings.goalWarningLoseAboveCurrent));
  });

  test('collectGoalWarnings warns when gain goal is below current weight', () {
    final warnings = collectGoalWarnings(
      goalType: GoalType.gain,
      targetWeightKg: 70,
      currentWeightKg: 75,
      targetDate: referenceDate.add(const Duration(days: 90)),
      referenceDate: referenceDate,
    );

    expect(warnings, contains(AppStrings.goalWarningGainBelowCurrent));
  });

  test('collectGoalWarnings warns for short target period', () {
    final warnings = collectGoalWarnings(
      goalType: GoalType.maintain,
      targetWeightKg: 75,
      currentWeightKg: 75,
      targetDate: referenceDate.add(const Duration(days: 7)),
      referenceDate: referenceDate,
    );

    expect(warnings, contains(AppStrings.goalWarningShortPeriod));
  });
}
