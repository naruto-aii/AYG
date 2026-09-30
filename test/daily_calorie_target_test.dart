import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/calculation/calorie_target_mode.dart';
import 'package:ayg/models/calculation/goal_pace.dart';
import 'package:ayg/models/calculation/landing_guidance.dart';
import 'package:ayg/models/calculation/weight_sample.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/services/daily_calorie_target_planner.dart';
import 'package:ayg/services/energy_target_calculation_service.dart';
import 'package:ayg/services/nutrition_engine.dart';
import 'package:ayg/services/weight_for_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = EnergyTargetCalculationService();
  const planner = DailyCalorieTargetPlanner();
  final referenceDate = DateTime(2026, 7, 21);
  final profile = UserProfile(
    birthDate: DateTime(1990, 1, 1),
    gender: Gender.male,
    heightCm: 175,
    weightKg: 75,
  );
  const settings = NutritionSettings(
    useHealthIntegration: false,
    activityLevel: ActivityLevel.moderate,
  );

  List<WeightSample> seriesEnding(
    DateTime end, {
    int count = 4,
    int spanDays = 21,
    double kg = 75,
  }) {
    return [
      for (var i = 0; i < count; i++)
        WeightSample(
          kg: kg,
          measuredAt: end.subtract(
            Duration(days: spanDays - i * (spanDays ~/ (count - 1))),
          ),
          source: WeightSource.manual,
        ),
    ];
  }

  group('weight selection', () {
    test('uses the newer measurement, not Health by default', () {
      final selection = selectWeight(
        samples: [
          WeightSample(
            kg: 70,
            measuredAt: DateTime(2026, 9, 1),
            source: WeightSource.health,
          ),
          WeightSample(
            kg: 71.2,
            measuredAt: DateTime(2026, 9, 30, 8),
            source: WeightSource.manual,
          ),
        ],
        reference: DateTime(2026, 9, 30, 12),
        fallbackKg: 70,
      );

      expect(selection.kg, 71.2);
      expect(selection.source, WeightSource.manual);
      expect(selection.ageLabel, '今日');
      expect(selection.usageLabel, '計算に使用: 71.2 kg · アプリ · 今日');
      expect(selection.stale, isFalse);
      expect(selection.healthUpdateStopped, isTrue);
      expect(selection.healthUpdateStoppedNote, contains('更新が止まっています'));
    });

    test('both older than 7 days does not increase the deficit later', () {
      final selection = selectWeight(
        samples: [
          WeightSample(
            kg: 75,
            measuredAt: DateTime(2026, 9, 1),
            source: WeightSource.manual,
          ),
          WeightSample(
            kg: 74,
            measuredAt: DateTime(2026, 9, 10),
            source: WeightSource.health,
          ),
        ],
        reference: DateTime(2026, 9, 30),
        fallbackKg: 75,
      );

      expect(selection.source, WeightSource.health);
      expect(selection.ageDays, greaterThan(7));
      expect(selection.stale, isTrue);
      expect(selection.staleRecordPrompt, contains('体重を記録してください'));
    });

    test(
      'fewer than 3 records or under 7 days stays on the initial formula',
      () {
        final short = describeWeightSeries(
          samples: seriesEnding(referenceDate, count: 2, spanDays: 20),
          reference: referenceDate,
          fallbackKg: 75,
        );
        final narrow = describeWeightSeries(
          samples: seriesEnding(referenceDate, count: 4, spanDays: 6),
          reference: referenceDate,
          fallbackKg: 75,
        );
        final ready = describeWeightSeries(
          samples: seriesEnding(referenceDate),
          reference: referenceDate,
          fallbackKg: 75,
        );

        expect(short.useLandingFormula, isFalse);
        expect(narrow.useLandingFormula, isFalse);
        expect(ready.useLandingFormula, isTrue);
        expect(ready.smoothedKg, closeTo(75, 0.01));
      },
    );
  });

  group('landing formula', () {
    final samples = seriesEnding(referenceDate);

    test('60 days and 5 kg needs 600 kcal and does not add last week', () {
      final result = service.calculate(
        profile: profile,
        goal: Goal(
          type: GoalType.lose,
          targetWeightKg: 70,
          targetDate: referenceDate.add(const Duration(days: 60)),
        ),
        settings: settings,
        weightSamples: samples,
        referenceDate: referenceDate,
      );

      expect(result.usesLandingFormula, isTrue);
      expect(result.rawBalanceKcal, closeTo(-600, 0.01));
      expect(
        result.goalFoodTargetKcal,
        closeTo(result.estimatedMaintenanceKcal! - 600, 0.01),
      );
      expect(result.guidance, isNull);

      final withFoodGap = NutritionEngine().calculateDailySummary(
        profile: profile,
        goal: Goal(
          type: GoalType.lose,
          targetWeightKg: 70,
          targetDate: referenceDate.add(const Duration(days: 60)),
        ),
        settings: settings,
        foodEntries: [
          FoodEntry(
            id: 'gap',
            name: '少ない記録',
            kcalPerUnit: 100,
            quantity: 1,
            loggedAt: referenceDate,
          ),
        ],
        exerciseEntries: const [],
        weightSamples: samples,
        referenceDate: referenceDate,
      );
      expect(withFoodGap.targetKcal, closeTo(result.goalFoodTargetKcal!, 0.01));
    });

    test('loss cap is the smaller of 1 kg and 1% per week', () {
      final cap = planner.lossCapKcalPerDay(75);
      expect(cap, closeTo(0.75 * 7200 / 7, 0.01));
      expect(cap, lessThan(1000));
      expect(planner.lossCapKcalPerDay(120), closeTo(7200 / 7, 0.01));
      expect(
        planner.gainCapKcalPerDay(75),
        closeTo(75 * 0.005 * 7200 / 7, 0.01),
      );
    });

    test('10 days and 5 kg stops at the safe cap and suggests a change', () {
      final result = service.calculate(
        profile: profile,
        goal: Goal(
          type: GoalType.lose,
          targetWeightKg: 70,
          targetDate: referenceDate.add(const Duration(days: 10)),
        ),
        settings: settings,
        weightSamples: samples,
        referenceDate: referenceDate,
      );
      final cap = planner.lossCapKcalPerDay(75);

      expect(result.rawBalanceKcal, closeTo(-3600, 0.01));
      expect(
        result.goalFoodTargetKcal,
        closeTo(result.estimatedMaintenanceKcal! - cap, 0.5),
      );
      expect(result.guidance?.kind, LandingGuidanceKind.exceedsSafeSpeed);
      expect(result.guidance!.message, contains('この目標日には届きません'));
      expect(result.guidance!.message, contains('安全な速度なら'));
      expect(result.guidance!.suggestedDate, isNotNull);
      expect(
        result.guidance!.recommended,
        isNot(LandingGuidanceAction.useStandardPace),
      );
    });

    test('stored slow pace does not change the single food target', () {
      final standard = service.calculate(
        profile: profile,
        goal: Goal(
          type: GoalType.lose,
          targetWeightKg: 70,
          targetDate: referenceDate.add(const Duration(days: 60)),
          goalPace: GoalPace.standard,
        ),
        settings: settings,
        goalPace: GoalPace.standard,
        weightSamples: samples,
        referenceDate: referenceDate,
      );
      final slow = service.calculate(
        profile: profile,
        goal: Goal(
          type: GoalType.lose,
          targetWeightKg: 70,
          targetDate: referenceDate.add(const Duration(days: 60)),
          goalPace: GoalPace.slow,
        ),
        settings: settings,
        goalPace: GoalPace.slow,
        weightSamples: samples,
        referenceDate: referenceDate,
      );

      expect(slow.speedCapKcal, closeTo(planner.lossCapKcalPerDay(75), 0.01));
      expect(
        slow.goalFoodTargetKcal,
        closeTo(standard.goalFoodTargetKcal!, 0.01),
      );
      expect(slow.guidance, isNull);
    });

    test('food target does not go below the sex-specific floor', () {
      final plan = planner.plan(
        maintenanceKcal: 1800,
        smoothedWeightKg: 75,
        goalWeightKg: 60,
        goalType: GoalType.lose,
        remainingDays: 10,
        gender: Gender.male,
        referenceDate: referenceDate,
        weightStale: false,
        clampBaseKcal: null,
        clampDays: 0,
      );
      expect(plan.foodTargetKcal, 1500);

      final female = planner.plan(
        maintenanceKcal: 1400,
        smoothedWeightKg: 55,
        goalWeightKg: 45,
        goalType: GoalType.lose,
        remainingDays: 10,
        gender: Gender.female,
        referenceDate: referenceDate,
        weightStale: false,
        clampBaseKcal: null,
        clampDays: 0,
      );
      expect(female.foodTargetKcal, greaterThanOrEqualTo(1200));
    });

    test('daily step stays within 150 kcal of the previous target', () {
      final result = service.calculate(
        profile: profile,
        goal: Goal(
          type: GoalType.lose,
          targetWeightKg: 70,
          targetDate: referenceDate.add(const Duration(days: 10)),
        ),
        settings: settings,
        weightSamples: samples,
        referenceDate: referenceDate,
        autoFoodTargetKcal: 2300,
        autoFoodTargetOn: referenceDate.subtract(const Duration(days: 1)),
      );

      expect(result.goalFoodTargetKcal, closeTo(2150, 0.01));
      expect(result.dailyStepLimited, isTrue);
    });

    test(
      'stale weight keeps the previous target instead of a larger deficit',
      () {
        final staleSamples = [
          for (var i = 0; i < 4; i++)
            WeightSample(
              kg: 75,
              measuredAt: referenceDate.subtract(Duration(days: 30 - i * 7)),
              source: WeightSource.manual,
            ),
        ];
        final result = service.calculate(
          profile: profile,
          goal: Goal(
            type: GoalType.lose,
            targetWeightKg: 70,
            targetDate: referenceDate.add(const Duration(days: 10)),
          ),
          settings: settings,
          weightSamples: staleSamples,
          referenceDate: referenceDate,
          autoFoodTargetKcal: 2200,
          autoFoodTargetOn: referenceDate.subtract(const Duration(days: 1)),
        );

        expect(result.heldForStaleWeight, isTrue);
        expect(result.goalFoodTargetKcal, 2200);
        expect(result.guidance, isNull);
      },
    );

    test('initial formula is unchanged when history is short', () {
      final initial = service.calculate(
        profile: profile,
        goal: Goal(
          type: GoalType.lose,
          targetWeightKg: 70,
          targetDate: referenceDate.add(const Duration(days: 90)),
        ),
        settings: settings,
        referenceDate: referenceDate,
      );
      expect(initial.usesLandingFormula, isFalse);
      expect(initial.dailyGoalAdjustmentKcal, closeTo(5 * 7200 / 90, 0.01));
    });
  });

  group('manual targets', () {
    test('weight and remaining days do not overwrite manual kcal or PFC', () {
      const manual = NutritionSettings(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
        calorieTargetMode: CalorieTargetMode.manual,
        manualTargetKcal: 1800,
        manualProteinG: 120,
        manualFatG: 50,
        manualCarbG: 180,
      );
      final engine = NutritionEngine();
      final first = engine.calculateDailySummary(
        profile: profile,
        goal: Goal(
          type: GoalType.lose,
          targetWeightKg: 70,
          targetDate: referenceDate.add(const Duration(days: 10)),
        ),
        settings: manual,
        foodEntries: const [],
        exerciseEntries: const [],
        weightSamples: seriesEnding(referenceDate),
        referenceDate: referenceDate,
      );
      final later = engine.calculateDailySummary(
        profile: profile.copyWith(weightKg: 80),
        goal: Goal(
          type: GoalType.lose,
          targetWeightKg: 70,
          targetDate: referenceDate.add(const Duration(days: 3)),
        ),
        settings: manual,
        foodEntries: const [],
        exerciseEntries: const [],
        weightSamples: seriesEnding(referenceDate, kg: 80),
        referenceDate: referenceDate.add(const Duration(days: 7)),
      );

      expect(first.targetKcal, 1800);
      expect(first.targetProteinG, 120);
      expect(first.targetFatG, 50);
      expect(first.targetCarbG, 180);
      expect(later.targetKcal, 1800);
      expect(later.targetProteinG, 120);
      expect(later.targetFatG, 50);
      expect(later.targetCarbG, 180);
      expect(first.energyBreakdown!.manualTargetsActive, isTrue);
      expect(first.energyBreakdown!.anchorUpdate, isNull);
    });
  });
}
