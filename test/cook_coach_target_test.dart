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
    expect(cookKcalGapLabel(80), '目標まであと 80kcal');
    expect(cookKcalGapLabel(0), '目標どおり');
    expect(cookMacroGapLabel('P', -0.6), 'P 0.6g 多い');
    expect(cookMacroGapLabel('F', 0.7), 'F あと 0.7g');
    expect(cookKcalGapLabel(-30), '30kcal 多い');
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
    expect(cookKcalGapLabel(parsed.patterns.single.gapKcal), '目標まであと 12kcal');
  });

  test('displayed gap is target minus the ingredient rows', () {
    const target = CookCoachMealTarget(
      slot: MealSlot.dinner,
      kcal: 650,
      proteinG: 32,
      fatG: 18,
      carbG: 75,
      remainingKcal: 650,
      remainingProteinG: 32,
      remainingFatG: 18,
      remainingCarbG: 75,
    );
    const lying = CookDish(
      kind: 'on_hand',
      name: '鶏むねとごはん',
      steps: ['鶏肉は中まで火を通す', 'ごはんを盛る'],
      extras: [],
      ingredients: [
        CookIngredient(
          name: '鶏むね肉',
          grams: 150,
          kcal: 162,
          proteinG: 36,
          fatG: 2,
          carbG: 0,
          source: 'db',
          foodCode: '11226',
        ),
        CookIngredient(
          name: 'ごはん',
          grams: 140,
          kcal: 235,
          proteinG: 4,
          fatG: 0,
          carbG: 52,
          source: 'db',
          foodCode: '1080',
        ),
      ],
      kcal: 420,
      proteinG: 36,
      fatG: 4,
      carbG: 52,
      gapKcal: 12,
      gapProteinG: 1,
      gapFatG: 0,
      gapCarbG: 2,
      withinTolerance: true,
    );
    final shown = alignCookDish(lying, target);
    expect(shown.kcal, 162 + 235);
    expect(shown.proteinG, 40);
    expect(shown.fatG, 2);
    expect(shown.carbG, 52);
    expect(shown.gapKcal, 650 - 397);
    expect(shown.gapProteinG, closeTo(32 - 40, 0.001));
    expect(shown.gapFatG, closeTo(18 - 2, 0.001));
    expect(shown.gapCarbG, closeTo(75 - 52, 0.001));
    expect(shown.withinTolerance, isFalse);
    expect(cookKcalGapLabel(shown.gapKcal), '目標まであと 253kcal');
  });
}
