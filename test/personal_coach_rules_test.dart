import 'dart:math';

import 'package:ayg/data/coach_food_catalog.dart';
import 'package:ayg/services/daily_coach.dart';
import 'package:flutter_test/flutter_test.dart';

import 'personal_coach_rules_validator.dart';

void main() {
  final foods = CoachFoodCatalog.stocks;
  final day = DateTime(2026, 10, 7, 12);
  final night = DateTime(2026, 10, 7, 22, 30);

  List<CoachMealProposal> propose(
    double remaining, {
    DateTime? now,
    Set<String> excluded = const {},
  }) {
    return planCoachMeals(
      foods: foods,
      excludedFoodCodes: excluded,
      remainingKcal: remaining,
      remainingProteinG: 0,
      remainingFatG: 0,
      remainingCarbG: 0,
      now: now ?? day,
    );
  }

  List<String> problemsFor(
    double remaining,
    List<CoachMealProposal> meals, {
    required bool nightTime,
  }) {
    final problems = <String>[];
    for (final meal in meals) {
      final found = PersonalCoachRules.validate(
        remainingKcal: remaining,
        night: nightTime,
        items: [
          for (final item in meal.components)
            CoachRuleItem(foodCode: item.foodCode, grams: item.grams),
        ],
      );
      if (found.isNotEmpty) {
        problems.add('${remaining.toStringAsFixed(0)} ${meal.headline}: ${found.join(' / ')}');
      }
    }
    return problems;
  }

  test('rules hold across the calorie sweep, night, and random days', () {
    final points = <double>[
      for (var kcal = -500; kcal <= 1500; kcal += 10) kcal.toDouble(),
      -1,
      0,
      1,
      49,
      50,
      51,
      249,
      250,
      251,
      449,
      450,
      451,
      649,
      650,
      651,
      849,
      850,
      851,
    ];
    var checked = 0;
    var violations = 0;
    var missing = 0;
    for (final remaining in points) {
      final meals = propose(remaining);
      if (remaining >= 50 && meals.isEmpty) {
        missing++;
      }
      final found = problemsFor(remaining, meals, nightTime: false);
      checked += meals.length;
      violations += found.length;
      if (found.isNotEmpty) {
        fail(found.first);
      }
    }
    for (var kcal = 50; kcal <= 1500; kcal += 10) {
      final meals = propose(kcal.toDouble(), now: night);
      if (meals.isEmpty) {
        missing++;
      }
      final found = problemsFor(kcal.toDouble(), meals, nightTime: true);
      checked += meals.length;
      violations += found.length;
      if (found.isNotEmpty) {
        fail(found.first);
      }
    }
    final random = Random(20261007);
    final excludable = [
      for (final food in CoachFoodCatalog.candidates)
        if (food.role == CoachFoodRole.main ||
            food.role == CoachFoodRole.side ||
            food.role == CoachFoodRole.fruit)
          food.foodCode,
    ];
    for (var i = 0; i < 1000; i++) {
      final remaining = 50 + random.nextInt(1451);
      final rate = random.nextDouble() * 0.4;
      final excluded = {
        for (final code in excludable)
          if (random.nextDouble() < rate) code,
      };
      final meals = propose(remaining.toDouble(), excluded: excluded);
      if (meals.isEmpty) {
        missing++;
      }
      final found = problemsFor(remaining.toDouble(), meals, nightTime: false);
      checked += meals.length;
      violations += found.length;
      if (found.isNotEmpty) {
        fail(found.first);
      }
    }
    // ignore: avoid_print
    print(
      'personal coach rules checked=$checked violations=$violations missing=$missing',
    );
    expect(violations, 0);
    expect(missing, 0);
    expect(checked, greaterThan(1000));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('meat and fish stay within one portion and the gram caps', () {
    for (final remaining in [260, 330, 440, 460, 550, 640, 700, 850, 1200]) {
      for (final meal in propose(remaining.toDouble())) {
        final animals = [
          for (final item in meal.components)
            if (CoachFoodCatalog.find(item.foodCode)?.subrole ==
                    CoachFoodSubrole.meat ||
                CoachFoodCatalog.find(item.foodCode)?.subrole ==
                    CoachFoodSubrole.fish)
              item,
        ];
        expect(animals.length, lessThanOrEqualTo(1), reason: '$remaining');
        if (animals.isEmpty) {
          continue;
        }
        final grams = animals.single.grams;
        if (remaining < 450) {
          expect(grams, 60);
        } else if (remaining < 650) {
          expect(grams, inInclusiveRange(60, 120));
        } else {
          expect(grams, inInclusiveRange(90, 150));
        }
      }
    }
  });

  test('a full meal has a staple, a main, and two sides with greens', () {
    for (final remaining in [460, 550, 640, 700, 850, 1200]) {
      final meals = propose(remaining.toDouble());
      expect(meals, isNotEmpty);
      for (final meal in meals) {
        final roles = [
          for (final item in meal.components)
            CoachFoodCatalog.find(item.foodCode)!.role,
        ];
        expect(roles.where((role) => role == CoachFoodRole.staple).length, 1);
        expect(
          roles.where((role) => role == CoachFoodRole.main).length,
          inInclusiveRange(1, 2),
        );
        final sides = [
          for (final item in meal.components)
            if (CoachFoodCatalog.find(item.foodCode)!.role == CoachFoodRole.side)
              CoachFoodCatalog.find(item.foodCode)!,
        ];
        expect(sides, hasLength(2));
        expect(sides.any((food) => food.isGreenYellowVegetable), isTrue);
        expect(meal.kcal, lessThanOrEqualTo(remaining < 850 ? remaining : 850));
      }
    }
  });

  test('the validator rejects broken meals', () {
    final meal = propose(550).first;
    final items = [
      for (final item in meal.components)
        CoachRuleItem(foodCode: item.foodCode, grams: item.grams),
    ];
    expect(
      PersonalCoachRules.validate(
        remainingKcal: 550,
        night: false,
        items: items,
      ),
      isEmpty,
    );

    List<CoachRuleItem> broken(List<CoachRuleItem> next) => next;
    expect(
      PersonalCoachRules.validate(
        remainingKcal: 550,
        night: false,
        items: [
          for (final item in items)
            CoachRuleItem(
              foodCode: item.foodCode,
              grams: item == items.first ? item.grams * 2 : item.grams,
            ),
        ],
      ),
      isNotEmpty,
    );
    expect(
      PersonalCoachRules.validate(
        remainingKcal: 550,
        night: false,
        items: broken(items.skip(1).toList()),
      ),
      isNotEmpty,
    );
    expect(
      PersonalCoachRules.validate(
        remainingKcal: 550,
        night: false,
        items: [
          ...items,
          const CoachRuleItem(foodCode: '11288', grams: 60),
        ],
      ),
      isNotEmpty,
    );
    expect(
      PersonalCoachRules.validate(
        remainingKcal: 550,
        night: false,
        items: [
          for (final item in items)
            if (CoachFoodCatalog.find(item.foodCode)!.role != CoachFoodRole.side)
              item,
        ],
      ),
      isNotEmpty,
    );
    expect(
      PersonalCoachRules.validate(
        remainingKcal: 550,
        night: false,
        items: [
          for (final item in items)
            if (item.foodCode == '12005')
              const CoachRuleItem(foodCode: '12005', grams: 150)
            else
              item,
          if (!items.any((item) => item.foodCode == '12005'))
            const CoachRuleItem(foodCode: '12005', grams: 150),
        ],
      ),
      isNotEmpty,
    );
    final animal = items.where((item) {
      final sub = CoachFoodCatalog.find(item.foodCode)!.subrole;
      return sub == CoachFoodSubrole.meat || sub == CoachFoodSubrole.fish;
    }).toList();
    if (animal.isNotEmpty) {
      expect(
        PersonalCoachRules.validate(
          remainingKcal: 550,
          night: false,
          items: [
            for (final item in items)
              if (item.foodCode == animal.single.foodCode)
                CoachRuleItem(
                  foodCode: item.foodCode,
                  grams: item.grams + 10,
                )
              else
                item,
          ],
        ),
        isNotEmpty,
      );
    } else {
      expect(
        PersonalCoachRules.validate(
          remainingKcal: 550,
          night: false,
          items: [
            ...items,
            const CoachRuleItem(foodCode: '11288', grams: 130),
          ],
        ),
        isNotEmpty,
      );
    }
    expect(
      PersonalCoachRules.validate(
        remainingKcal: 550,
        night: false,
        items: [
          for (final item in items)
            if (CoachFoodCatalog.find(item.foodCode)!.isGreenYellowVegetable)
              const CoachRuleItem(foodCode: '06065', grams: 70)
            else
              item,
        ],
      ),
      isNotEmpty,
    );
  });
}
