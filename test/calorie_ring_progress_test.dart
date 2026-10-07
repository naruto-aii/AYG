import 'dart:math' as math;

import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/utils/calorie_ring_progress.dart';
import 'package:ayg/widgets/design/calorie_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calorieRingProgress', () {
    test('without exercise it is intake divided by the target', () {
      expect(
        calorieRingProgress(
          intakeKcal: 500,
          remainingKcal: 1500,
          targetKcal: 2000,
        ),
        closeTo(0.25, 1e-12),
      );
    });

    test('is continuous and never snaps to 10% or 25% steps', () {
      for (var intake = 1; intake < 2000; intake += 37) {
        final value = calorieRingProgress(
          intakeKcal: intake.toDouble(),
          remainingKcal: (2000 - intake).toDouble(),
          targetKcal: 2000,
        );
        expect(value, closeTo(intake / 2000, 1e-12));
      }
      expect(
        calorieRingProgress(
          intakeKcal: 1234,
          remainingKcal: 766,
          targetKcal: 2000,
        ),
        closeTo(0.617, 1e-12),
      );
    });

    test('exercise widens the budget so a full ring means 0 kcal left', () {
      // 目標 2,000、運動 400 → 今日食べてよいのは 2,400。
      expect(
        calorieRingProgress(
          intakeKcal: 2000,
          remainingKcal: 400,
          targetKcal: 2000,
        ),
        closeTo(2000 / 2400, 1e-12),
      );
      expect(
        calorieRingProgress(
          intakeKcal: 2400,
          remainingKcal: 0,
          targetKcal: 2000,
        ),
        1,
      );
    });

    test('over the target is a full ring', () {
      expect(
        calorieRingProgress(
          intakeKcal: 2300,
          remainingKcal: -300,
          targetKcal: 2000,
        ),
        1,
      );
    });

    test('target 0, nothing eaten, or broken numbers are an empty ring', () {
      expect(
        calorieRingProgress(
          intakeKcal: 800,
          remainingKcal: -800,
          targetKcal: 0,
        ),
        0,
      );
      expect(
        calorieRingProgress(
          intakeKcal: 0,
          remainingKcal: 2000,
          targetKcal: 2000,
        ),
        0,
      );
      expect(
        calorieRingProgress(
          intakeKcal: double.nan,
          remainingKcal: 2000,
          targetKcal: 2000,
        ),
        0,
      );
    });
  });

  group('ringTrimRange', () {
    final cap = ringRoundCapFraction(radius: 58, strokeWidth: 10);

    test('the round caps are one line width of the circumference', () {
      expect(cap, closeTo(10 / (2 * math.pi * 58), 1e-12));
    });

    test('visible length (trim + caps) equals the progress', () {
      for (final progress in [0.05, 0.25, 0.5, 0.9, 0.97, 0.99]) {
        final range = ringTrimRange(progress: progress, capFraction: cap)!;
        final visibleStart = range.from - cap / 2;
        final visibleEnd = range.to + cap / 2;
        expect(visibleStart, closeTo(0, 1e-12));
        expect(visibleEnd, closeTo(progress, 1e-12));
      }
    });

    test('97% leaves a visible gap instead of looking closed', () {
      final range = ringTrimRange(progress: 0.97, capFraction: cap)!;
      expect(range.to + cap / 2, lessThan(1));
    });

    test('0 draws nothing and 1 or more draws the whole circle', () {
      expect(ringTrimRange(progress: 0, capFraction: cap), isNull);
      expect(ringTrimRange(progress: 1, capFraction: cap), (
        from: 0.0,
        to: 1.0,
      ));
      expect(ringTrimRange(progress: 1.4, capFraction: cap), (
        from: 0.0,
        to: 1.0,
      ));
    });

    test('shorter than the caps keeps the raw range', () {
      expect(ringTrimRange(progress: cap / 2, capFraction: cap), (
        from: 0.0,
        to: cap / 2,
      ));
    });
  });

  group('MealWidgetFigures.ringProgress', () {
    test('uses the same numbers as the 今日あと label', () {
      const figures = MealWidgetFigures(
        remainingKcal: 1600,
        intakeKcal: 800,
        burnKcal: 400,
        targetKcal: 2000,
      );
      expect(figures.ringProgress, closeTo(800 / 2400, 1e-12));
    });

    test('a meal button moves the ring by exactly its share', () {
      const before = MealWidgetFigures(
        remainingKcal: 1500,
        intakeKcal: 500,
        burnKcal: 0,
        targetKcal: 2000,
      );
      final after = applyMealWidgetFigures(
        figures: before,
        intakeDelta: 333,
        burnDelta: 0,
      );
      expect(before.ringProgress, closeTo(0.25, 1e-12));
      expect(after.ringProgress, closeTo(833 / 2000, 1e-12));
    });

    test('an exercise button moves the ring back like the label', () {
      const before = MealWidgetFigures(
        remainingKcal: 0,
        intakeKcal: 2000,
        burnKcal: 0,
        targetKcal: 2000,
      );
      expect(before.ringProgress, 1);
      final after = applyMealWidgetFigures(
        figures: before,
        intakeDelta: 0,
        burnDelta: 500,
      );
      expect(after.remainingKcal, 500);
      expect(after.ringProgress, closeTo(2000 / 2500, 1e-12));
    });

    test('a full white ring only when 0 kcal is left; overage is full', () {
      const exact = MealWidgetFigures(
        remainingKcal: 0,
        intakeKcal: 2200,
        burnKcal: 200,
        targetKcal: 2000,
      );
      expect(exact.ringProgress, 1);
      const almost = MealWidgetFigures(
        remainingKcal: 1,
        intakeKcal: 2199,
        burnKcal: 200,
        targetKcal: 2000,
      );
      expect(almost.ringProgress, lessThan(1));
      const over = MealWidgetFigures(
        remainingKcal: 0,
        intakeKcal: 2300,
        burnKcal: 0,
        targetKcal: 2000,
        overageKcal: 300,
      );
      expect(over.ringProgress, 1);
    });

    test('missing or zero target and empty figures are safe', () {
      expect(const MealWidgetFigures().ringProgress, 0);
      expect(
        const MealWidgetFigures(
          remainingKcal: 0,
          intakeKcal: 500,
          targetKcal: 0,
          overageKcal: 500,
        ).ringProgress,
        0,
      );
      // target キーが無い古いデータは、残りから描ける。
      expect(
        const MealWidgetFigures(
          remainingKcal: 1500,
          intakeKcal: 500,
        ).ringProgress,
        closeTo(0.25, 1e-12),
      );
      // 残りが無ければ 摂取 ÷ 目標。
      expect(
        const MealWidgetFigures(intakeKcal: 500, targetKcal: 2000).ringProgress,
        closeTo(0.25, 1e-12),
      );
    });
  });

  testWidgets('CalorieRing paints for any progress without errors', (
    tester,
  ) async {
    for (final progress in [0.0, 0.01, 0.5, 0.97, 1.0, 1.5]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: CalorieRing(
              label: '今日あと',
              value: '1,000',
              progress: progress,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
