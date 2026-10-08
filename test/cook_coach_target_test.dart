import 'package:ayg/data/coach_food_catalog.dart';
import 'package:ayg/services/cook_coach.dart';
import 'package:ayg/services/cook_coach_target.dart';
import 'package:ayg/services/personal_coach_planner.dart';
import 'package:ayg/utils/meal_slot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('meal kcal matches the personal coach day budget', () {
    const remaining = 1800.0;
    final morning = DateTime(2026, 10, 8, 8);
    final evening = DateTime(2026, 10, 8, 18);
    final late = DateTime(2026, 10, 8, 22, 30);

    final morningPlan = planPersonalCoachDay(
      foods: CoachFoodCatalog.stocks,
      excludedFoodCodes: const {},
      remainingKcal: remaining,
      now: morning,
    ).first;
    final breakfast = morningPlan.meals.firstWhere(
      (meal) => meal.slot == MealSlot.breakfast,
    );
    expect(
      cookCoachSlotBudget(
        remainingKcal: remaining,
        now: morning,
        slot: MealSlot.breakfast,
      ),
      breakfast.budgetKcal,
    );
    expect(
      cookCoachSlotBudget(
        remainingKcal: remaining,
        now: morning,
        slot: MealSlot.snack,
      ),
      personalCoachSnackReserveKcal,
    );

    final dinnerPlan = planPersonalCoachDay(
      foods: CoachFoodCatalog.stocks,
      excludedFoodCodes: const {},
      remainingKcal: remaining,
      now: evening,
    ).first;
    expect(
      cookCoachSlotBudget(
        remainingKcal: remaining,
        now: evening,
        slot: MealSlot.dinner,
      ),
      dinnerPlan.meals.single.budgetKcal,
    );
    expect(dinnerPlan.meals.single.budgetKcal, personalCoachMealCapKcal);

    expect(
      cookCoachSlotBudget(
        remainingKcal: 800,
        now: late,
        slot: MealSlot.snack,
      ),
      personalCoachSnackCapKcal,
    );
    expect(cookCoachDefaultSlot(morning), MealSlot.breakfast);
    expect(cookCoachDefaultSlot(evening), MealSlot.dinner);
    expect(cookCoachDefaultSlot(late), MealSlot.snack);
  });

  test('PFC for the meal is the remaining share of that kcal', () {
    final target = cookCoachMealTarget(
      now: DateTime(2026, 10, 8, 18),
      slot: MealSlot.dinner,
      remainingKcal: 1700,
      remainingProteinG: 90,
      remainingFatG: 50,
      remainingCarbG: 200,
    );
    expect(target.kcal, personalCoachMealCapKcal);
    expect(target.proteinG, closeTo(90 * 850 / 1700, 0.001));
    expect(target.fatG, closeTo(50 * 850 / 1700, 0.001));
    expect(target.carbG, closeTo(200 * 850 / 1700, 0.001));
  });

  test('gap text and dictated ingredient text', () {
    expect(cookKcalGapLabel(80), 'あと＋80kcal');
    expect(cookKcalGapLabel(0), '目標どおり');
    expect(cookKcalGapLabel(-30), '目標より30kcal多い');
    expect(
      cookIngredientNames('卵、玉ねぎ，豚こま\n卵'),
      ['卵', '玉ねぎ', '豚こま'],
    );
  });

  test('a result keeps the gap and whether it landed inside tolerance', () {
    final parsed = parseCookCoachResult({
      'patterns': [
        {
          'kind': 'on_hand',
          'name': '塩鶏',
          'steps': ['中まで火を通す'],
          'kcal': 400,
          'protein_g': 40,
          'fat_g': 8,
          'carb_g': 35,
          'gap_kcal': 12,
          'gap_protein_g': 1.5,
          'gap_fat_g': 0,
          'gap_carb_g': -2,
          'within_tolerance': true,
          'ingredients': [
            {
              'name': '鶏むね肉',
              'grams': 150,
              'kcal': 162,
              'source': 'db',
              'food_code': '11226',
            },
          ],
        },
      ],
    });
    expect(parsed, isNotNull);
    expect(parsed!.patterns.single.withinTolerance, isTrue);
    expect(parsed.patterns.single.gapKcal, 12);
    expect(cookKcalGapLabel(parsed.patterns.single.gapKcal), 'あと＋12kcal');
  });
}
