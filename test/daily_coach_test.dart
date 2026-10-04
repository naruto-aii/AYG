import 'package:ayg/data/coach_food_catalog.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/services/daily_coach.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 4, 12);

  CoachFoodStock stock(
    String code, {
    required double kcal,
    required double protein,
    required double fat,
    required double carb,
  }) {
    return CoachFoodStock(
      candidate: CoachFoodCatalog.find(code)!,
      nutrition: CoachFoodNutrition(
        foodCode: code,
        kcal: kcal,
        proteinG: protein,
        fatG: fat,
        carbG: carb,
        officialName: 'official $code',
      ),
    );
  }

  final rice = stock('01088', kcal: 156, protein: 2.5, fat: 0.3, carb: 37.1);
  final egg = stock('12005', kcal: 134, protein: 12.5, fat: 10.4, carb: 0.3);
  final chicken = stock('11288', kcal: 177, protein: 38.8, fat: 3.3, carb: 0.1);
  final onigiri = stock('01111', kcal: 170, protein: 2.7, fat: 0.3, carb: 39.4);

  List<CoachMealProposal> meals({
    List<CoachFoodStock>? foods,
    Set<String> excluded = const {},
    double remainingKcal = 301,
    double remainingProteinG = 0,
    double remainingFatG = 6,
    double remainingCarbG = 56,
  }) {
    return planCoachMeals(
      foods: foods ?? [rice, egg, chicken, onigiri],
      excludedFoodCodes: excluded,
      remainingKcal: remainingKcal,
      remainingProteinG: remainingProteinG,
      remainingFatG: remainingFatG,
      remainingCarbG: remainingCarbG,
    );
  }

  test('catalog is the 34 coach foods and does not say salad chicken', () {
    expect(CoachFoodCatalog.candidates, hasLength(34));
    expect(CoachFoodCatalog.codes.toSet(), hasLength(34));
    expect(CoachFoodCatalog.find('01111')?.displayName, '具なしおにぎり');
    expect(CoachFoodCatalog.find('01111')?.contentsNote, '中身は米だけ');
    expect(CoachFoodCatalog.find('11229')?.displayName, '鶏ささみ（ゆで）');
    final names = CoachFoodCatalog.candidates.map((food) => food.displayName);
    expect(names, isNot(contains('サラダチキン')));
  });

  test('egg rice is one named meal and protein drift is said in one line', () {
    final proposals = meals();
    expect(proposals, hasLength(3));
    expect(proposals.first.headline, '卵かけご飯（白米150gと卵1個）');
    expect(proposals.first.foodCodes, {'01088', '12005'});
    expect(proposals.first.kcal, closeTo(301, 0.01));
    expect(proposals.first.macroNote, 'これだとたんぱく質が約10g多くなります。今提案できる範囲で最善です。');
    final sets = proposals.map((meal) => meal.foodCodes.join(',')).toSet();
    expect(sets, hasLength(3));
    final text = proposals.map((meal) => meal.headline).join('\n');
    expect(text, isNot(contains('今日は提案できません')));
    expect(text, isNot(contains('サラダチキン')));
  });

  test('foods eaten in the last 3 days are left out', () {
    final proposals = meals(excluded: {'01088'});
    expect(
      proposals.every((meal) => !meal.foodCodes.contains('01088')),
      isTrue,
    );
    expect(proposals.first.headline, isNot(contains('卵かけご飯')));
  });

  test('the same food is not listed three times at different grams', () {
    final proposals = meals(foods: [rice], remainingKcal: 500);
    expect(proposals, hasLength(1));
    expect(proposals.single.headline, '白米（めし）（300g）');
    expect(proposals.single.components.single.units, 2);
  });

  test('plain onigiri says the filling is only rice', () {
    final proposals = meals(foods: [onigiri], remainingKcal: 170);
    expect(proposals.single.headline, '具なしおにぎり（1個100g、中身は米だけ）');
  });

  test('unnamed pairs use food names', () {
    final proposals = meals(
      foods: [rice, chicken],
      remainingKcal: 234 + 177,
      remainingProteinG: 100,
    );
    expect(proposals.first.headline, '白米と鶏むね（白米150gと鶏むね100g）');
    expect(proposals.first.macroNote, contains('少なくなります'));
  });

  test('last 3 days include today and exclude the 4th day', () {
    expect(coachLoggedWithinDays(DateTime(2026, 10, 4), now, 3), isTrue);
    expect(coachLoggedWithinDays(DateTime(2026, 10, 2), now, 3), isTrue);
    expect(coachLoggedWithinDays(DateTime(2026, 10, 1), now, 3), isFalse);
    expect(coachLoggedWithinDays(DateTime(2026, 9, 27), now, 3), isFalse);
    expect(coachLoggedWithinDays(DateTime(2026, 9, 5), now, 30), isTrue);
    expect(coachLoggedWithinDays(DateTime(2026, 9, 4), now, 30), isFalse);
  });

  test(
    'running beyond 45 minutes states the required distance and the cap',
    () {
      final message = buildCoachExerciseMessage(
        overageKcal: 744,
        weightKg: 60,
        now: now,
        exercises: [
          ExerciseEntry(
            id: 'run',
            name: 'ランニング',
            activityId: 'running',
            durationMin: 20,
            distanceKm: 2,
            burnedKcal: 120,
            loggedAt: DateTime(2026, 10, 3),
          ),
        ],
      );
      expect(
        message,
        '今日の超過を戻すには、ランニング12.4kmが必要です。今日やるなら3kmまでにします。残りは明日以降の食事で調整しましょう。',
      );
    },
  );

  test('a legacy run id still caps the running distance', () {
    final message = buildCoachExerciseMessage(
      overageKcal: 744,
      weightKg: 60,
      now: now,
      exercises: [
        ExerciseEntry(
          id: 'run',
          name: 'ランニング',
          activityId: 'run_jog',
          durationMin: 20,
          distanceKm: 2,
          burnedKcal: 120,
          loggedAt: DateTime(2026, 10, 3),
        ),
      ],
    );
    expect(message, contains('今日やるなら3kmまでにします'));
  });

  test(
    'someone with no history is capped at 20 minutes of walking or bodyweight',
    () {
      final large = buildCoachExerciseMessage(
        overageKcal: 744,
        weightKg: 60,
        now: now,
        exercises: const [],
      );
      expect(
        large,
        '今日の超過を戻すには、ランニング12.4kmが必要です。今日やるなら、歩くか軽い自重で20分までにします。残りは明日以降の食事で調整しましょう。',
      );

      final small = buildCoachExerciseMessage(
        overageKcal: 30,
        weightKg: 60,
        now: now,
        exercises: const [],
      );
      expect(small, '今日やるなら、歩くか軽い自重で12分にします。');
    },
  );

  test('a day without weight does not state a distance', () {
    final message = buildCoachExerciseMessage(
      overageKcal: 400,
      weightKg: null,
      now: now,
      exercises: const [],
    );
    expect(message, isNot(contains('km')));
    expect(message, contains('体重がないため、距離は出していません'));
    expect(message, contains('歩くか軽い自重で20分'));
  });

  test(
    'bodyweight uses minutes and the running distance only when 45 minutes is not enough',
    () {
      final message = buildCoachExerciseMessage(
        overageKcal: 200,
        weightKg: 60,
        now: now,
        exercises: [
          ExerciseEntry(
            id: 'bw',
            name: '自重トレーニング',
            activityId: 'bodyweight',
            durationMin: 20,
            burnedKcal: 40,
            loggedAt: DateTime(2026, 10, 1),
          ),
        ],
      );
      expect(
        message,
        '今日の超過を戻すには、ランニング3.3kmが必要です。今日やるなら自重トレーニング30分までにします。残りは明日以降の食事で調整しましょう。',
      );
    },
  );

  test('an old run outside 30 days does not set the cap', () {
    final message = buildCoachExerciseMessage(
      overageKcal: 30,
      weightKg: 60,
      now: now,
      exercises: [
        ExerciseEntry(
          id: 'old',
          name: 'ランニング',
          activityId: 'running',
          durationMin: 40,
          distanceKm: 8,
          burnedKcal: 400,
          loggedAt: DateTime(2026, 8, 1),
        ),
      ],
    );
    expect(message, contains('歩くか軽い自重'));
  });

  test(
    'a short run that fits under the cap does not add the required distance',
    () {
      final message = buildCoachExerciseMessage(
        overageKcal: 30,
        weightKg: 60,
        now: now,
        exercises: [
          ExerciseEntry(
            id: 'run',
            name: 'ランニング',
            activityId: 'running',
            durationMin: 30,
            distanceKm: 5,
            burnedKcal: 300,
            loggedAt: DateTime(2026, 10, 2),
          ),
        ],
      );
      expect(message, '今日やるならランニング0.5kmにします。');
    },
  );

  test('the second open on the same day needs Calonavi Plus', () {
    expect(coachAllowsAnotherOpen(opensToday: 0, isPlus: false), isTrue);
    expect(coachAllowsAnotherOpen(opensToday: 1, isPlus: false), isFalse);
    expect(coachAllowsAnotherOpen(opensToday: 3, isPlus: true), isTrue);
  });
}
