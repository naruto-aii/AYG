import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/calculation/goal_pace.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/services/energy_target_calculation_service.dart';
import 'package:ayg/models/health_snapshot.dart';

import 'helpers/isar_test_helper.dart';

void main() {
  group('GoalPace persistence', () {
    test('Isar saves and reloads goal pace', () async {
      final harness = await setUpIsarHarness();

      await harness.userRepository.saveGoal(
        Goal(
          type: GoalType.lose,
          targetWeightKg: 68,
          targetDate: DateTime(2026, 12, 31),
          goalPace: GoalPace.slow,
        ),
      );

      final loaded = await harness.userRepository.loadGoal();
      expect(loaded?.goalPace, GoalPace.slow);
    });

    test('legacy goal without explicit pace defaults to standard', () async {
      final harness = await setUpIsarHarness();

      await harness.userRepository.saveGoal(
        Goal(
          type: GoalType.gain,
          targetWeightKg: 75,
          targetDate: DateTime(2026, 12, 31),
        ),
      );

      expect(
        (await harness.userRepository.loadGoal())?.goalPace,
        GoalPace.standard,
      );
    });
  });

  group('GoalPace calculation', () {
    const service = EnergyTargetCalculationService();
    final profile = UserProfile(
      birthDate: DateTime(1990, 1, 1),
      gender: Gender.male,
      heightCm: 175,
      weightKg: 75,
    );
    final settings = const NutritionSettings(
      useHealthIntegration: false,
      activityLevel: ActivityLevel.moderate,
    );
    final referenceDate = DateTime(2026, 7, 21);

    test('slow pace raises lose food target versus standard', () {
      final goal = Goal(
        type: GoalType.lose,
        targetWeightKg: 70,
        targetDate: referenceDate.add(const Duration(days: 90)),
      );

      final standard = service.calculate(
        profile: profile,
        goal: goal.copyWith(goalPace: GoalPace.standard),
        settings: settings,
        goalPace: GoalPace.standard,
        referenceDate: referenceDate,
      );
      final slow = service.calculate(
        profile: profile,
        goal: goal.copyWith(goalPace: GoalPace.slow),
        settings: settings,
        goalPace: GoalPace.slow,
        referenceDate: referenceDate,
      );

      expect(
        slow.goalFoodTargetKcal!,
        greaterThan(standard.goalFoodTargetKcal!),
      );
    });

    test('maintain ignores pace adjustment', () {
      final result = service.calculate(
        profile: profile,
        goal: Goal(
          type: GoalType.maintain,
          targetWeightKg: 70,
          targetDate: referenceDate.add(const Duration(days: 90)),
          goalPace: GoalPace.slow,
        ),
        settings: settings,
        goalPace: GoalPace.slow,
        referenceDate: referenceDate,
      );

      expect(result.dailyGoalAdjustmentKcal, 0);
      expect(
        result.goalFoodTargetKcal,
        closeTo(result.estimatedMaintenanceKcal!, 0.01),
      );
    });

    test('health active energy is not added to food target', () {
      final result = service.calculate(
        profile: profile,
        goal: Goal(
          type: GoalType.lose,
          targetWeightKg: 70,
          targetDate: referenceDate.add(const Duration(days: 90)),
          goalPace: GoalPace.standard,
        ),
        settings: settings,
        healthSnapshot: const HealthSnapshot(activeEnergyBurnedKcal: 600),
        goalPace: GoalPace.standard,
        referenceDate: referenceDate,
      );

      expect(result.usedHealthActiveEnergyForTarget, isFalse);
      expect(result.healthActiveEnergyKcal, 600);
    });

    test('GoalPace.fromName falls back to standard', () {
      expect(GoalPace.fromName(null), GoalPace.standard);
      expect(GoalPace.fromName('unknown'), GoalPace.standard);
      expect(GoalPace.fromName('slow'), GoalPace.slow);
    });
  });
}
