import 'package:ayg/data/coach_food_catalog.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/repositories/coach_proposal_log.dart';
import 'package:ayg/services/daily_coach.dart';
import 'package:ayg/services/daily_coach_session.dart';
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

  test('catalog is the 66 coach foods and does not say salad chicken', () {
    expect(CoachFoodCatalog.candidates, hasLength(66));
    expect(CoachFoodCatalog.codes.toSet(), hasLength(66));
    expect(CoachFoodCatalog.find('01111')?.displayName, 'おにぎり（具なし）');
    expect(CoachFoodCatalog.find('01111')?.contentsNote, '中身は米だけ');
    expect(CoachFoodCatalog.find('01039')?.unitGrams, 300);
    expect(CoachFoodCatalog.find('01128')?.unitGrams, 300);
    final names = CoachFoodCatalog.candidates.map((food) => food.displayName);
    expect(names, isNot(contains('サラダチキン')));
  });

  test('a meal lists foods and amounts without a dish title', () {
    final proposals = meals(
      foods: [
        for (final code in ['01111', '12005', '06268'])
          CoachFoodCatalog.stockFor(CoachFoodCatalog.find(code)!),
      ],
      remainingKcal: 400,
    );
    expect(proposals, isNotEmpty);
    expect(proposals.first.headline, contains('中身は米だけ'));
    expect(proposals.first.headline, isNot(contains('卵かけご飯')));
    expect(proposals.first.bandLabel, '軽食');
    for (final meal in proposals) {
      for (final item in meal.components) {
        expect(item.units, 1);
        expect(item.grams, isNot(300));
      }
    }
  });

  test('recent mains are left out and staples are not', () {
    final withoutChicken = meals(
      foods: CoachFoodCatalog.stocks,
      excluded: {'11288'},
      remainingKcal: 450,
    );
    expect(withoutChicken, isNotEmpty);
    expect(
      withoutChicken.every((meal) => !meal.foodCodes.contains('11288')),
      isTrue,
    );
    final riceStillThere = meals(
      foods: CoachFoodCatalog.stocks,
      excluded: {'01088'},
      remainingKcal: 450,
    );
    expect(
      riceStillThere.any((meal) => meal.foodCodes.contains('01088')),
      isTrue,
    );
  });

  test('portions stay inside the published choices', () {
    final proposals = meals(
      foods: CoachFoodCatalog.stocks,
      remainingKcal: 700,
    );
    expect(proposals, isNotEmpty);
    expect(proposals.length, lessThanOrEqualTo(10));
    for (final meal in proposals) {
      expect(meal.bandLabel, '一食（しっかり）');
      expect(meal.headline, isNot(contains('卵かけご飯')));
      for (final item in meal.components) {
        final food = CoachFoodCatalog.find(item.foodCode)!;
        expect(
          food.portions.any(
            (portion) =>
                portion.grams == item.grams &&
                (portion.tier == CoachPortionTier.hearty ||
                    portion.tier == CoachPortionTier.any),
          ),
          isTrue,
        );
      }
    }
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
        '戻すにはランニングで約124分です。今日やるなら30分までにします。30分で約180kcal戻ります。残りの約564kcalは明日以降の食事で。',
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
    expect(message, contains('ランニング'));
    expect(message, contains('分'));
    expect(message, isNot(contains('km')));
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
      expect(large, contains('速歩き'));
      expect(large, contains('20分で約48kcal戻ります'));
      expect(large, isNot(contains('ランニング')));

      final small = buildCoachExerciseMessage(
        overageKcal: 30,
        weightKg: 60,
        now: now,
        exercises: const [],
      );
      expect(small, '今日はほぼちょうどです。');
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
    expect(message, '体重が未登録のため、戻るカロリーを計算できません。');
    expect(message, isNot(contains('歩くか軽い自重')));
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
      expect(message, contains('自重トレーニング'));
      expect(message, contains('30分'));
      expect(message, contains('kcal戻ります'));
      expect(message, isNot(contains('ランニング')));
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
    expect(message, '今日はほぼちょうどです。');
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
      expect(message, '今日はほぼちょうどです。');
    },
  );

  test(
    'the registrable running amount is the capped distance in the sentence',
    () {
      final proposal = buildCoachExerciseProposal(
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
        proposal!.message,
        '戻すにはランニングで約124分です。今日やるなら30分までにします。30分で約180kcal戻ります。残りの約564kcalは明日以降の食事で。',
      );
      expect(proposal.activityId, 'running');
      expect(proposal.unit, CoachExerciseUnit.minutes);
      expect(proposal.amount, 30);
      expect(proposal.canRegister, isTrue);

      final asProposed = coachExerciseEntry(
        proposal: proposal,
        amount: 30,
        weightKg: 60,
        id: 'run-3',
        loggedAt: now,
      );
      expect(asProposed!.distanceKm, 3);
      expect(asProposed.netKcal, 180);
      expect(asProposed.activityId, 'running');

      final edited = coachExerciseEntry(
        proposal: proposal,
        amount: 42,
        weightKg: 60,
        id: 'run-4',
        loggedAt: now,
      );
      expect(edited!.distanceKm, closeTo(4.2, 0.001));
      expect(edited.netKcal, closeTo(252, 0.001));
    },
  );

  test('a short run registers the distance written in the sentence', () {
    final proposal = buildCoachExerciseProposal(
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
    expect(proposal!.canRegister, isFalse);
    expect(proposal.amount, isNull);
    expect(proposal.unit, isNull);
  });

  test('novice walking registers the shown minutes as distance', () {
    final large = buildCoachExerciseProposal(
      overageKcal: 744,
      weightKg: 60,
      now: now,
      exercises: const [],
    );
    expect(large!.activityId, 'walk_brisk');
    expect(large.unit, CoachExerciseUnit.minutes);
    expect(large.amount, 20);
    final entry = coachExerciseEntry(
      proposal: large,
      amount: 20,
      weightKg: 60,
      id: 'walk',
      loggedAt: now,
    );
    expect(entry!.activityId, 'walk_brisk');
    expect(entry.distanceKm, closeTo(20 / 60 * 4.828032, 0.000001));
    expect(entry.netKcal, closeTo(0.5 * 60 * entry.distanceKm!, 0.001));

    final small = buildCoachExerciseProposal(
      overageKcal: 30,
      weightKg: 60,
      now: now,
      exercises: const [],
    );
    expect(small!.amount, isNull);
    expect(small.unit, isNull);
    expect(small.message, '今日はほぼちょうどです。');
  });

  test('a day without weight does not offer exercise registration', () {
    final proposal = buildCoachExerciseProposal(
      overageKcal: 400,
      weightKg: null,
      now: now,
      exercises: const [],
    );
    expect(proposal!.canRegister, isFalse);
    expect(proposal.needsWeight, isTrue);
    expect(proposal.amount, isNull);
    expect(
      coachExerciseEntry(
        proposal: proposal,
        amount: 20,
        weightKg: null,
        id: 'none',
        loggedAt: now,
      ),
      isNull,
    );
  });

  test('bodyweight registers the shown minutes and rejects a fraction', () {
    final proposal = buildCoachExerciseProposal(
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
    expect(proposal!.activityId, 'bodyweight');
    expect(proposal.unit, CoachExerciseUnit.minutes);
    expect(proposal.amount, 30);
    final entry = coachExerciseEntry(
      proposal: proposal,
      amount: 30,
      weightKg: 60,
      id: 'bw',
      loggedAt: now,
    );
    expect(entry!.durationMin, 30);
    expect(entry.distanceKm, isNull);
    expect(entry.netKcal, closeTo((2.8 - 1) * 3.5 * 60 / 200 * 30, 0.001));
    expect(coachWholeMinutes(12.4), isNull);
    expect(
      coachExerciseEntry(
        proposal: proposal,
        amount: 12.4,
        weightKg: 60,
        id: 'fraction',
        loggedAt: now,
      ),
      isNull,
    );
  });

  test('edited meal grams scale the stored quantity', () {
    expect(
      coachMealConsumedAmount(units: 1, proposedGrams: 150, editedGrams: 150),
      1,
    );
    expect(
      coachMealConsumedAmount(units: 1, proposedGrams: 150, editedGrams: 100),
      closeTo(100 / 150, 0.0001),
    );
    expect(
      coachMealConsumedAmount(units: 2, proposedGrams: 300, editedGrams: 200),
      closeTo(2 * 200 / 300, 0.0001),
    );
    expect(
      coachMealConsumedAmount(units: 1, proposedGrams: 150, editedGrams: 0),
      isNull,
    );
  });

  test('meals and exercise are not logged together', () {
    const meal = CoachMealProposal(
      headline: '白米',
      kcal: 234,
      proteinG: 4,
      fatG: 1,
      carbG: 50,
      components: [
        CoachMealComponent(
          foodCode: '01088',
          displayName: '白米（めし）',
          officialName: null,
          units: 1,
          grams: 150,
          kcalPerUnit: 234,
          proteinPerUnit: 4,
          fatPerUnit: 1,
          carbPerUnit: 50,
        ),
      ],
    );
    const both = DailyCoachLoadResult(
      status: DailyCoachStatus.ready,
      meals: [meal],
      exerciseMessage: '今日やるなら3kmまでにします。',
    );
    expect(both.offersMeals, isFalse);
    expect(both.offersExercise, isFalse);
    expect(coachProposalRecords(now: now, result: both), isEmpty);

    const mealsOnly = DailyCoachLoadResult(
      status: DailyCoachStatus.ready,
      focus: DailyCoachFocus.meals,
      meals: [meal],
      exerciseMessage: '今日やるなら3kmまでにします。',
    );
    expect(mealsOnly.offersMeals, isTrue);
    expect(mealsOnly.offersExercise, isFalse);
    expect(coachProposalRecords(now: now, result: mealsOnly), hasLength(1));

    const exerciseOnly = DailyCoachLoadResult(
      status: DailyCoachStatus.ready,
      focus: DailyCoachFocus.exercise,
      meals: [meal],
      exercise: CoachExerciseProposal(
        message: '今日やるなら3kmまでにします。',
        activityId: 'running',
        amount: 3,
        unit: CoachExerciseUnit.kilometers,
      ),
    );
    expect(exerciseOnly.offersMeals, isFalse);
    expect(exerciseOnly.offersExercise, isTrue);
    expect(coachProposalRecords(now: now, result: exerciseOnly), hasLength(1));
  });
}
