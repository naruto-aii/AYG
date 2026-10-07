import 'dart:math';

import 'package:ayg/data/coach_food_catalog.dart';
import 'package:ayg/services/daily_coach.dart';
import 'package:ayg/services/personal_coach_planner.dart';
import 'package:ayg/utils/meal_slot.dart';
import 'package:flutter_test/flutter_test.dart';

import 'personal_coach_rules_validator.dart';

/// 2,438kcal 残りで間食しか出なかった不具合の再発防止と、1日の案の規則。
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
    expect(meal.kcal, lessThanOrEqualTo(personalCoachMealCapKcal),
        reason: reason);
  }

  test('just after midnight with 2,438kcal left, it plans three full meals',
      () {
    final now = DateTime(2026, 10, 8, 1, 10);
    final days = plan(2438, now);
    expect(days, isNotEmpty);
    for (final day in days) {
      final meals = [
        for (final entry in day.meals)
          if (entry.slot != MealSlot.snack) entry,
      ];
      expect(meals.map((entry) => entry.slot).toList(), [
        MealSlot.breakfast,
        MealSlot.lunch,
        MealSlot.dinner,
      ]);
      for (final entry in meals) {
        expectFullMeal(entry.meal, entry.label);
      }
      expect(day.kcal, lessThanOrEqualTo(2438));
      expect(day.kcal, greaterThanOrEqualTo(2438 * 0.85),
          reason: 'the plan must get close to the remaining kcal');
      final snacks = day.meals.where((entry) => entry.slot == MealSlot.snack);
      expect(snacks.length, lessThanOrEqualTo(personalCoachSnackLimit));
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

  test('slots follow the clock', () {
    expect(personalCoachRemainingSlots(DateTime(2026, 10, 8, 3)),
        [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner]);
    expect(personalCoachRemainingSlots(DateTime(2026, 10, 8, 10, 59)),
        [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner]);
    expect(personalCoachRemainingSlots(DateTime(2026, 10, 8, 11)),
        [MealSlot.lunch, MealSlot.dinner]);
    expect(personalCoachRemainingSlots(DateTime(2026, 10, 8, 15)),
        [MealSlot.dinner]);
    expect(personalCoachRemainingSlots(DateTime(2026, 10, 8, 22)), isEmpty);
  });

  test('at noon 1,500kcal becomes lunch and dinner', () {
    final days = plan(1500, DateTime(2026, 10, 8, 12));
    expect(days, isNotEmpty);
    for (final day in days) {
      final slots = day.meals.map((entry) => entry.slot).toList();
      expect(slots.take(2).toList(), [MealSlot.lunch, MealSlot.dinner]);
      expect(day.kcal, inInclusiveRange(1200, 1500));
    }
  });

  test('a single dinner with a big remainder says what is left', () {
    final now = DateTime(2026, 10, 8, 19);
    final plans = planCoachDay(
      foods: foods,
      excludedFoodCodes: const {},
      remainingKcal: 2438,
      now: now,
    );
    expect(plans, isNotEmpty);
    expect(plans.first.meals.first.slotLabel, '夕食');
    expect(plans.first.note, contains('850kcal'));
  });

  test('late evening stays a light meal, not a snack only', () {
    final days = plan(800, DateTime(2026, 10, 7, 22, 30));
    expect(days, isNotEmpty);
    for (final day in days) {
      expect(day.meals, hasLength(1));
      expect(day.meals.single.meal.band, PersonalCoachBand.light);
      expect(day.kcal, lessThan(450));
    }
  });

  test('each meal keeps the single-meal rules and the day varies mains', () {
    final random = Random(20261008);
    final hours = [1, 7, 9, 12, 14, 16, 19, 21, 23];
    var checked = 0;
    for (var i = 0; i < 120; i++) {
      final remaining = 50 + random.nextInt(2950).toDouble();
      final now = DateTime(2026, 10, 8, hours[random.nextInt(hours.length)]);
      final late = personalCoachIsLateEvening(now);
      for (final day in plan(remaining, now)) {
        expect(day.kcal, lessThanOrEqualTo(remaining));
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
