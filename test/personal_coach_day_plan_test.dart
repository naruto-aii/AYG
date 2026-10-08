import 'dart:math';

import 'package:ayg/data/coach_food_catalog.dart';
import 'package:ayg/services/daily_coach.dart';
import 'package:ayg/services/personal_coach_planner.dart';
import 'package:ayg/utils/meal_slot.dart';
import 'package:flutter_test/flutter_test.dart';

import 'personal_coach_rules_validator.dart';

/// 2,438kcal 残りで間食しか出なかった不具合の再発防止と、時間帯ごとの1日の案の規則。
///
/// 0:00〜10:59 朝食・昼食・間食・夕食 / 11:00〜14:59 昼食・間食・夕食 /
/// 15:00〜21:59 夕食だけ / 22:00〜23:59 間食だけ。0〜4時は朝の扱い。
void main() {
  final foods = CoachFoodCatalog.stocks;

  List<PlannedCoachDay> plan(double remaining, DateTime now,
      {Set<String> excluded = const {}}) {
    return planPersonalCoachDay(
      foods: foods,
      excludedFoodCodes: excluded,
      remainingKcal: remaining,
      now: now,
    );
  }

  List<CoachDayPlan> shown(double remaining, DateTime now) {
    return planCoachDay(
      foods: foods,
      excludedFoodCodes: const {},
      remainingKcal: remaining,
      now: now,
    );
  }

  CoachFoodRole roleOf(PlannedCoachItem item) =>
      CoachFoodCatalog.find(item.foodCode)!.role;

  void expectFullMeal(PlannedCoachMeal meal, String reason) {
    final roles = meal.items.map((item) => item.role).toList();
    expect(roles.where((r) => r == CoachFoodRole.staple).length, 1,
        reason: reason);
    expect(roles.where((r) => r == CoachFoodRole.main).length,
        inInclusiveRange(1, 2), reason: reason);
    expect(roles.where((r) => r == CoachFoodRole.side).length, 2,
        reason: reason);
    expect(meal.kcal, inInclusiveRange(personalCoachMealFloorKcal * 0.8,
        personalCoachMealCapKcal), reason: reason);
  }

  void expectSnack(PlannedCoachDayMeal entry, String reason) {
    expect(entry.slot, MealSlot.snack, reason: reason);
    expect(entry.label, '間食', reason: reason);
    expect(entry.meal.band, PersonalCoachBand.snack, reason: reason);
    expect(entry.meal.kcal, lessThanOrEqualTo(personalCoachSnackCapKcal),
        reason: reason);
    for (final item in entry.meal.items) {
      expect(roleOf(item), anyOf(CoachFoodRole.dairy, CoachFoodRole.fruit),
          reason: reason);
    }
  }

  void expectMorningDay(double remaining, DateTime now) {
    final days = plan(remaining, now);
    expect(days, isNotEmpty);
    for (final day in days) {
      expect(day.meals.map((entry) => entry.slot).toList(), [
        MealSlot.breakfast,
        MealSlot.lunch,
        MealSlot.snack,
        MealSlot.dinner,
      ]);
      expect(day.meals.map((entry) => entry.label).toList(),
          ['朝食', '昼食', '間食', '夕食']);
      for (final entry in day.meals) {
        if (entry.slot == MealSlot.snack) {
          expectSnack(entry, entry.label);
        } else {
          expectFullMeal(entry.meal, entry.label);
        }
      }
      expect(day.kcal, lessThanOrEqualTo(remaining));
      expect(day.kcal, greaterThanOrEqualTo(remaining * 0.95),
          reason: 'meals + snack must reach 95% of the remaining kcal');
    }
  }

  test('1:10 with 2,438kcal left: breakfast, lunch, snack, dinner', () {
    final now = DateTime(2026, 10, 8, 1, 10);
    expect(personalCoachIsLateEvening(now), isFalse);
    expectMorningDay(2438, now);
    final plans = shown(2438, now);
    expect(plans.first.meals.map((meal) => meal.slotLabel).toList(),
        ['朝食', '昼食', '間食', '夕食']);
    // 1食の上限に届かない端数（調味料の分の余白）には一文を出さない。
    expect(plans.first.note, isNull);
  });

  test('6:00 is the same four slots', () {
    expectMorningDay(2438, DateTime(2026, 10, 8, 6));
    expectMorningDay(1800, DateTime(2026, 10, 8, 6));
  });

  test('12:00 with 1,500kcal: lunch, snack, dinner', () {
    final days = plan(1500, DateTime(2026, 10, 8, 12));
    expect(days, isNotEmpty);
    for (final day in days) {
      expect(day.meals.map((entry) => entry.slot).toList(),
          [MealSlot.lunch, MealSlot.snack, MealSlot.dinner]);
      expectFullMeal(day.meals[0].meal, '昼食');
      expectSnack(day.meals[1], '間食');
      expectFullMeal(day.meals[2].meal, '夕食');
      expect(day.kcal, inInclusiveRange(1500 * 0.95, 1500));
    }
  });

  test('16:00 with 1,200kcal: dinner only, no snack, and a note', () {
    final now = DateTime(2026, 10, 8, 16);
    final days = plan(1200, now);
    expect(days, isNotEmpty);
    for (final day in days) {
      expect(day.meals, hasLength(1));
      expect(day.meals.single.slot, MealSlot.dinner);
      expect(day.meals.single.label, '夕食');
      expectFullMeal(day.meals.single.meal, '夕食');
    }
    final plans = shown(1200, now);
    for (final plan in plans) {
      expect(plan.meals.map((meal) => meal.slotLabel).toList(), ['夕食']);
      expect(plan.note, contains('850kcal'));
      expect(plan.note, contains('残りは約${(1200 - plan.kcal).round()}kcal'));
    }
  });

  test('22:30 with 800kcal: snacks only, with a gentle note', () {
    final now = DateTime(2026, 10, 8, 22, 30);
    final days = plan(800, now);
    expect(days, isNotEmpty);
    for (final day in days) {
      expect(day.meals.length, inInclusiveRange(1, personalCoachSnackLimit));
      for (final entry in day.meals) {
        expectSnack(entry, '22:30');
      }
      final codes = [
        for (final entry in day.meals)
          for (final item in entry.meal.items) item.foodCode,
      ];
      expect(codes.toSet().length, codes.length, reason: 'no repeated food');
    }
    for (final plan in shown(800, now)) {
      expect(plan.note, '夜遅い時間なので、間食までにしています。残りは無理に食べなくて大丈夫です。');
      expect(plan.note, isNot(contains('精度')));
    }
  });

  test('the old night rule no longer turns a full day into one snack', () {
    final meals = planCoachMeals(
      foods: foods,
      excludedFoodCodes: const {},
      remainingKcal: 2438,
      remainingProteinG: 0,
      remainingFatG: 0,
      remainingCarbG: 0,
      now: DateTime(2026, 10, 8, 1, 10),
    );
    expect(meals, isNotEmpty);
    expect(meals.first.bandLabel, '一食（しっかり）');
  });

  test('slots follow the clock and 0-4時 is morning, not night', () {
    const morning = [
      MealSlot.breakfast,
      MealSlot.lunch,
      MealSlot.snack,
      MealSlot.dinner,
    ];
    for (final hour in [0, 1, 2, 3, 4, 5, 6, 10]) {
      expect(personalCoachRemainingSlots(DateTime(2026, 10, 8, hour)), morning,
          reason: '$hour時');
      expect(personalCoachIsLateEvening(DateTime(2026, 10, 8, hour)), isFalse);
    }
    expect(personalCoachRemainingSlots(DateTime(2026, 10, 8, 10, 59)), morning);
    expect(personalCoachRemainingSlots(DateTime(2026, 10, 8, 11)),
        [MealSlot.lunch, MealSlot.snack, MealSlot.dinner]);
    expect(personalCoachRemainingSlots(DateTime(2026, 10, 8, 14, 59)),
        [MealSlot.lunch, MealSlot.snack, MealSlot.dinner]);
    expect(personalCoachRemainingSlots(DateTime(2026, 10, 8, 15)),
        [MealSlot.dinner]);
    expect(personalCoachRemainingSlots(DateTime(2026, 10, 8, 21, 59)),
        [MealSlot.dinner]);
    expect(personalCoachRemainingSlots(DateTime(2026, 10, 8, 22)),
        [MealSlot.snack]);
    expect(personalCoachRemainingSlots(DateTime(2026, 10, 8, 23, 59)),
        [MealSlot.snack]);
  });

  test('0-14時 plans reach 95% of what the caps allow, never over 100%', () {
    for (final hour in [1, 12]) {
      final meals = hour < 11 ? 3 : 2;
      for (var remaining = 500.0; remaining <= 3000; remaining += 100) {
        // 1食 850kcal、間食は乳製品・果物で最大およそ150kcal（ヨーグルト＋果物）。
        final reachable = min(remaining, meals * personalCoachMealCapKcal + 150);
        final days = plan(remaining, DateTime(2026, 10, 8, hour));
        expect(days, isNotEmpty, reason: '$hour時 $remaining');
        for (final day in days) {
          expect(day.kcal, lessThanOrEqualTo(remaining));
          expect(day.kcal, greaterThanOrEqualTo(reachable * 0.95),
              reason: '$hour時 $remaining '
                  '${day.meals.map((e) => '${e.label}${e.meal.kcal}').join('/')}');
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('registered slots are left out and the rest is planned again', () {
    final morning = planPersonalCoachDay(
      foods: foods,
      excludedFoodCodes: const {},
      remainingKcal: 1726,
      now: DateTime(2026, 10, 8, 6, 10),
      skipSlots: {MealSlot.breakfast},
    );
    expect(morning, isNotEmpty);
    for (final day in morning) {
      expect(day.meals.map((entry) => entry.slot).toList(),
          [MealSlot.lunch, MealSlot.snack, MealSlot.dinner]);
      expect(day.kcal, inInclusiveRange(1726 * 0.95, 1726));
    }
    final noon = planPersonalCoachDay(
      foods: foods,
      excludedFoodCodes: const {},
      remainingKcal: 900,
      now: DateTime(2026, 10, 8, 12),
      skipSlots: {MealSlot.lunch, MealSlot.snack},
    );
    for (final day in noon) {
      expect(day.meals.map((entry) => entry.slot).toList(), [MealSlot.dinner]);
    }
    expect(
      planPersonalCoachDay(
        foods: foods,
        excludedFoodCodes: const {},
        remainingKcal: 900,
        now: DateTime(2026, 10, 8, 16),
        skipSlots: {MealSlot.dinner},
      ),
      isEmpty,
    );
    // 22時以降の間食は、昼間に間食を登録していても出す。
    expect(
      personalCoachPlannedSlots(DateTime(2026, 10, 8, 22, 30), {MealSlot.snack}),
      [MealSlot.snack],
    );
  });

  test('15-21時 never adds snacks, even with a big remainder', () {
    for (final hour in [15, 18, 21]) {
      for (final remaining in [500.0, 900.0, 1500.0, 2438.0]) {
        for (final day in plan(remaining, DateTime(2026, 10, 8, hour))) {
          expect(day.meals.map((entry) => entry.slot).toList(),
              [MealSlot.dinner], reason: '$hour時 $remaining');
        }
      }
    }
  });

  test('each meal keeps the single-meal rules and the day varies mains', () {
    final random = Random(20261008);
    final hours = [1, 4, 7, 9, 12, 14, 16, 19, 21, 22, 23];
    var checked = 0;
    for (var i = 0; i < 120; i++) {
      final remaining = 50 + random.nextInt(2950).toDouble();
      final now = DateTime(2026, 10, 8, hours[random.nextInt(hours.length)]);
      final late = personalCoachIsLateEvening(now);
      for (final day in plan(remaining, now)) {
        expect(day.kcal, lessThanOrEqualTo(remaining));
        expect(
          day.meals.where((entry) => entry.slot == MealSlot.snack).length,
          lessThanOrEqualTo(late ? personalCoachSnackLimit : 1),
        );
        if (late) {
          expect(day.meals.every((entry) => entry.slot == MealSlot.snack),
              isTrue);
        }
        final mains = <String>[];
        for (final entry in day.meals) {
          final problems = PersonalCoachRules.validate(
            remainingKcal: entry.budgetKcal,
            night: late,
            items: [
              for (final item in entry.meal.items)
                CoachRuleItem(foodCode: item.foodCode, grams: item.grams),
            ],
          );
          expect(problems, isEmpty,
              reason: '$remaining @${now.hour} ${entry.label} '
                  '${entry.meal.headline}');
          checked++;
          for (final item in entry.meal.items) {
            if (roleOf(item) == CoachFoodRole.main) {
              mains.add(item.foodCode);
            }
          }
        }
        // 同じ日の中で同じ主菜を繰り返さない（候補が尽きる場合を除く）。
        expect(mains.toSet().length, greaterThanOrEqualTo(mains.length - 1));
      }
    }
    expect(checked, greaterThan(200));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
