import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/models/goal.dart';
import 'package:ayg/services/macro_target_calculation_service.dart';

void main() {
  const service = MacroTargetCalculationService();

  group('MacroTargetCalculationService', () {
    test('lose without strength uses lower protein g per kg', () {
      final result = service.calculate(
        goalType: GoalType.lose,
        goalFoodTargetKcal: 2000,
        referenceWeightKg: 75,
        hasStrengthTrainingHabit: false,
      );

      expect(result.proteinGPerKg, 1.6);
      expect(result.proteinG, 120);
      expect(
        result.fatEnergyRatio,
        MacroTargetCalculationService.defaultFatEnergyRatio,
      );
    });

    test('strength training increases protein g per kg', () {
      final result = service.calculate(
        goalType: GoalType.lose,
        goalFoodTargetKcal: 2000,
        referenceWeightKg: 75,
        hasStrengthTrainingHabit: true,
      );

      expect(result.proteinGPerKg, 1.9);
    });

    test('P x 4 + F x 9 + C x 4 matches target within tolerance', () {
      final result = service.calculate(
        goalType: GoalType.maintain,
        goalFoodTargetKcal: 2200,
        referenceWeightKg: 68,
        hasStrengthTrainingHabit: true,
      );

      final total = result.proteinKcal + result.fatKcal + result.carbKcal;
      expect(total, closeTo(2200, 1.0));
    });

    test('carbs are residual after protein and fat', () {
      final result = service.calculate(
        goalType: GoalType.gain,
        goalFoodTargetKcal: 2500,
        referenceWeightKg: 70,
      );

      final expectedCarbKcal = 2500 - result.proteinKcal - result.fatKcal;
      expect(result.carbKcal, closeTo(expectedCarbKcal, 0.01));
    });
  });
}
