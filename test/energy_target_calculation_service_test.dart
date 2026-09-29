import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/calculation/goal_pace.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/health_snapshot.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/services/energy_target_calculation_service.dart';

void main() {
  const service = EnergyTargetCalculationService();
  final referenceDate = DateTime(2026, 7, 21);

  final maleProfile = UserProfile(
    birthDate: DateTime(1990, 1, 1),
    gender: Gender.male,
    heightCm: 175,
    weightKg: 75,
  );

  group('EnergyTargetCalculationService', () {
    test('maintenance uses REE times lifestyle factor only', () {
      final result = service.calculate(
        profile: maleProfile,
        goal: Goal(
          type: GoalType.maintain,
          targetWeightKg: 75,
          targetDate: referenceDate.add(const Duration(days: 90)),
        ),
        settings: const NutritionSettings(
          useHealthIntegration: true,
          activityLevel: ActivityLevel.moderate,
        ),
        healthSnapshot: const HealthSnapshot(activeEnergyBurnedKcal: 500),
        referenceDate: referenceDate,
      );

      final ree = (10 * 75) + (6.25 * 175) - (5 * 36) + 5;
      expect(result.estimatedReeKcal, closeTo(ree, 0.01));
      expect(
        result.estimatedMaintenanceKcal,
        closeTo(ree * ActivityLevel.moderate.factor, 0.01),
      );
      expect(result.usedHealthActiveEnergyForTarget, isFalse);
      expect(result.healthActiveEnergyKcal, 500);
    });

    test('lose applies paced adjustment', () {
      final standard = service.calculate(
        profile: maleProfile,
        goal: Goal(
          type: GoalType.lose,
          targetWeightKg: 70,
          targetDate: referenceDate.add(const Duration(days: 90)),
        ),
        settings: const NutritionSettings(
          useHealthIntegration: false,
          activityLevel: ActivityLevel.moderate,
        ),
        goalPace: GoalPace.standard,
        referenceDate: referenceDate,
      );
      final slow = service.calculate(
        profile: maleProfile,
        goal: Goal(
          type: GoalType.lose,
          targetWeightKg: 70,
          targetDate: referenceDate.add(const Duration(days: 90)),
        ),
        settings: const NutritionSettings(
          useHealthIntegration: false,
          activityLevel: ActivityLevel.moderate,
        ),
        goalPace: GoalPace.slow,
        referenceDate: referenceDate,
      );

      expect(
        standard.goalFoodTargetKcal!,
        lessThan(standard.estimatedMaintenanceKcal!),
      );
      expect(
        slow.goalFoodTargetKcal!,
        greaterThan(standard.goalFoodTargetKcal!),
      );
    });

    test('gender other is unavailable without arbitrary coefficient', () {
      final result = service.calculate(
        profile: UserProfile(
          birthDate: DateTime(1990, 1, 1),
          gender: Gender.other,
          heightCm: 175,
          weightKg: 75,
        ),
        goal: Goal(
          type: GoalType.maintain,
          targetWeightKg: 75,
          targetDate: referenceDate.add(const Duration(days: 90)),
        ),
        settings: const NutritionSettings(
          useHealthIntegration: false,
          activityLevel: ActivityLevel.moderate,
        ),
        referenceDate: referenceDate,
      );

      expect(result.canEstimateRee, isFalse);
      expect(result.unavailableReason, isNotNull);
    });

    test('under 18 is unavailable', () {
      final result = service.calculate(
        profile: UserProfile(
          birthDate: DateTime(2010, 1, 1),
          gender: Gender.male,
          heightCm: 170,
          weightKg: 60,
        ),
        goal: Goal(
          type: GoalType.maintain,
          targetWeightKg: 60,
          targetDate: referenceDate.add(const Duration(days: 90)),
        ),
        settings: const NutritionSettings(
          useHealthIntegration: false,
          activityLevel: ActivityLevel.moderate,
        ),
        referenceDate: referenceDate,
      );

      expect(result.canEstimateRee, isFalse);
    });
  });
}
