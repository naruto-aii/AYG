import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/models/alcohol_entry.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/services/exercise_calorie_calculator.dart';
import 'package:ayg/services/remaining_calorie_service.dart';

void main() {
  const service = RemainingCalorieService();
  const calculator = ExerciseCalorieCalculator();

  group('RemainingCalorieService', () {
    test('uses net exercise only in remaining formula', () {
      final remaining = service.calculate(
        baseDailyFoodTargetKcal: 2000,
        intakeKcal: 500,
        exerciseNetKcal: 300,
      );
      expect(remaining, 1800);
    });

    test('includes alcohol in intake sum', () {
      final day = DateTime(2026, 7, 21);
      final intake = service.sumIntakeKcal(
        foodEntries: [
          FoodEntry(
            id: 'f1',
            name: 'rice',
            quantity: 1,
            kcalPerUnit: 300,
            loggedAt: day,
          ),
        ],
        alcoholEntries: [
          AlcoholEntry(
            id: 'a1',
            beverageName: 'beer',
            amount: 500,
            unit: 'ml',
            alcoholPercentage: 5,
            totalCalories: 200,
            pureAlcoholGrams: 20,
            alcoholCalories: 140,
            consumedAt: day,
          ),
        ],
        selectedDay: day,
      );
      expect(intake, 500);
    });

    test('sums exercise net kcal for selected day only', () {
      final day = DateTime(2026, 7, 21);
      final otherDay = DateTime(2026, 7, 20);
      final net = service.sumExerciseNetKcal(
        exerciseEntries: [
          ExerciseEntry(
            id: 'e1',
            name: 'run',
            durationMin: 30,
            burnedKcal: 300,
            loggedAt: day,
            grossKcal: 300,
            netKcal: 250,
          ),
          ExerciseEntry(
            id: 'e2',
            name: 'walk',
            durationMin: 20,
            burnedKcal: 100,
            loggedAt: otherDay,
            netKcal: 80,
          ),
        ],
        selectedDay: day,
      );
      expect(net, 250);
    });

    test('legacy exercise without net uses burnedKcal fallback', () {
      final day = DateTime(2026, 7, 21);
      final net = service.sumExerciseNetKcal(
        exerciseEntries: [
          ExerciseEntry(
            id: 'legacy',
            name: 'old run',
            durationMin: 30,
            burnedKcal: 180,
            loggedAt: day,
          ),
        ],
        selectedDay: day,
      );
      expect(net, 180);
    });

    test('does not double-count gross when net is present', () {
      final day = DateTime(2026, 7, 21);
      final net = service.sumExerciseNetKcal(
        exerciseEntries: [
          ExerciseEntry(
            id: 'e1',
            name: 'run',
            durationMin: 30,
            burnedKcal: 300,
            loggedAt: day,
            grossKcal: 300,
            netKcal: 250,
          ),
        ],
        selectedDay: day,
      );
      expect(net, 250);
      expect(net, isNot(300));
    });

    test('reports overage without clamping to zero', () {
      final breakdown = service.calculateBreakdown(
        baseDailyFoodTargetKcal: 2000,
        foodEntries: [
          FoodEntry(
            id: 'f1',
            name: 'meal',
            quantity: 1,
            kcalPerUnit: 2500,
            loggedAt: DateTime(2026, 7, 21),
          ),
        ],
        alcoholEntries: const [],
        exerciseEntries: const [],
        selectedDay: DateTime(2026, 7, 21),
      );

      expect(breakdown.rawRemainingKcal, -500);
      expect(breakdown.isOverage, isTrue);
      expect(breakdown.overageKcal, 500);
    });
  });

  group('ExerciseCalorieCalculator', () {
    test('computes gross and net from MET formula', () {
      final estimate = calculator.estimate(
        met: 6,
        weightKg: 70,
        durationMinutes: 30,
      );
      expect(estimate, isNotNull);
      expect(estimate!.grossKcal, closeTo(220.5, 0.01));
      expect(estimate.netKcal, closeTo(183.75, 0.01));
    });

    test('rejects invalid weight and duration', () {
      expect(
        calculator.estimate(met: 6, weightKg: 0, durationMinutes: 30),
        isNull,
      );
      expect(
        calculator.estimate(met: 6, weightKg: 70, durationMinutes: 0),
        isNull,
      );
    });
  });
}
