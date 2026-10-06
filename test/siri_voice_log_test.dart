import 'dart:convert';

import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/services/siri_voice_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final loggedAt = DateTime(2026, 10, 1, 8, 30);

  SiriFoodRecord sasami() {
    return SiriFoodRecord.official(
      foodCode: '11227',
      name: '＜鳥肉類＞　にわとり　［若どり・副品目］　ささみ　生',
      speakName: 'ささみ',
      matchTexts: const ['ささみ', 'ササミ'],
      baseAmount: 100,
      unit: FoodUnitType.g,
      kcalPerBase: 98,
      proteinPerBase: 23.9,
      fatPerBase: 0.8,
      carbPerBase: 0.1,
    );
  }

  SiriVoiceContext context({
    bool paid = true,
    double? weightKg = 60,
    List<SiriFoodRecord>? foods,
    List<SiriMealTemplate> mealTemplates = const [],
    List<SiriWorkoutTemplate> workoutTemplates = const [],
  }) {
    return SiriVoiceContext(
      paid: paid,
      ownerUserId: 'user-1',
      weightKg: weightKg,
      foods: foods ?? [sasami()],
      mealTemplates: mealTemplates,
      workoutTemplates: workoutTemplates,
    );
  }

  SiriVoiceResult finish(
    SiriVoicePlan plan,
    SiriAnswer answer, {
    double? weightKg = 60,
  }) {
    return commitSiriVoice(
      plan: plan,
      answer: answer,
      loggedAt: loggedAt,
      ownerUserId: 'user-1',
      weightKg: weightKg,
      newId: () => 'id-1',
    );
  }

  test('food is repeated and saved only after yes', () {
    final plan = planSiriFood(
      context: context(),
      name: 'ささみ',
      quantity: '300g',
    );

    expect(plan.asksConfirmation, isTrue);
    expect(plan.spoken, 'ささみ300gの食事でいいですね');

    final declined = finish(plan, SiriAnswer.no);
    expect(declined.food, isNull);
    expect(declined.status, SiriVoiceStatus.declined);

    final silent = finish(plan, SiriAnswer.silence);
    expect(silent.food, isNull);
    expect(silent.status, SiriVoiceStatus.silence);

    final saved = finish(plan, SiriAnswer.yes);
    expect(saved.status, SiriVoiceStatus.registered);
    expect(saved.food!.name, 'ささみ');
    expect(saved.food!.consumedAmount, 300);
    expect(saved.food!.loggedAt, loggedAt);
    expect(saved.food!.totalKcal, 294);
    expect(saved.food!.officialFoodCode, '11227');
    expect(saved.exercise, isNull);
  });

  test('a spoken meal phrase is parsed before the repeat', () {
    final plan = planSiriFood(
      context: context(),
      name: 'Hey Siri、カロナビで、食事にささみを300グラム。',
      quantity: '',
    );

    expect(plan.spoken, 'ささみ300gの食事でいいですね');
    expect(finish(plan, SiriAnswer.yes).food!.consumedAmount, 300);
  });

  test(
    'speech without the app name or the meal or exercise marker is not saved',
    () {
      final noApp = planSiriFood(
        context: context(),
        name: '食事にささみを300グラム',
        quantity: '',
      );
      final noKind = planSiriExercise(
        context: context(),
        name: 'カロナビで、ジョギングを30分',
        quantity: '',
      );
      final wrongKind = planSiriFood(
        context: context(),
        name: 'カロナビで、運動にささみを300グラム',
        quantity: '',
      );

      expect(noApp.asksConfirmation, isFalse);
      expect(noApp.spoken, 'アプリ名が無いので登録しません');
      expect(noKind.spoken, 'ジョギング30分の運動でいいですね');
      expect(wrongKind.spoken, contains('ささみは見つかりません'));
      expect(wrongKind.status, SiriVoiceStatus.rescue);
      expect(finish(noApp, SiriAnswer.yes).registered, isFalse);
      expect(finish(noKind, SiriAnswer.yes).exercise!.durationMin, 30);
      expect(finish(wrongKind, SiriAnswer.yes).registered, isFalse);
    },
  );

  test('a missing food is not saved even after yes', () {
    final plan = planSiriFood(
      context: context(),
      name: 'うなぎ',
      quantity: '100g',
    );

    expect(plan.asksConfirmation, isFalse);
    expect(plan.status, SiriVoiceStatus.rescue);
    expect(plan.spoken, contains('うなぎは見つかりません'));
    expect(plan.searchQuery, 'うなぎ');
    expect(finish(plan, SiriAnswer.yes).food, isNull);
  });

  test('a partial food name is not guessed as a match', () {
    final plan = planSiriFood(context: context(), name: 'ささ', quantity: '100g');

    expect(plan.status, SiriVoiceStatus.rescue);
    expect(finish(plan, SiriAnswer.yes).registered, isFalse);
  });

  test('two foods with the same name are offered as choices', () {
    final plan = planSiriFood(
      context: context(
        foods: [
          sasami(),
          SiriFoodRecord.official(
            foodCode: '99999',
            name: '別のささみ',
            speakName: 'ささみ',
            matchTexts: const ['ささみ'],
            baseAmount: 100,
            unit: FoodUnitType.g,
            kcalPerBase: 100,
          ),
        ],
      ),
      name: 'ささみ',
      quantity: '100g',
    );

    expect(plan.asksChoice, isTrue);
    expect(plan.choices, hasLength(2));
    expect(plan.spoken, contains('どれですか'));
    expect(finish(plan, SiriAnswer.yes).food, isNull);

    final chosen = resolveSiriChoice(
      context: context(
        foods: [
          sasami(),
          SiriFoodRecord.official(
            foodCode: '99999',
            name: '別のささみ',
            speakName: 'ささみ',
            matchTexts: const ['ささみ'],
            baseAmount: 100,
            unit: FoodUnitType.g,
            kcalPerBase: 100,
          ),
        ],
      ),
      plan: plan,
      choiceId: '11227',
    );
    expect(chosen.spoken, 'ささみ100gの食事でいいですね');
    expect(finish(chosen, SiriAnswer.yes).food!.officialFoodCode, '11227');
  });

  test('unpaid speech does not save food or exercise', () {
    final food = planSiriFood(
      context: context(paid: false),
      name: 'ささみ',
      quantity: '300g',
    );
    final exercise = planSiriExercise(
      context: context(paid: false),
      name: '水泳',
      quantity: '30分',
    );

    expect(food.spoken, 'こちらはカロナビ+の機能です');
    expect(exercise.spoken, 'こちらはカロナビ+の機能です');
    expect(finish(food, SiriAnswer.yes).registered, isFalse);
    expect(finish(exercise, SiriAnswer.yes).registered, isFalse);
  });

  test('exercise is repeated and saved only after yes', () {
    final plan = planSiriExercise(
      context: context(),
      name: 'カロナビで、運動に水泳を30分',
      quantity: '',
    );

    expect(plan.spoken, '水泳30分の運動でいいですね');
    expect(finish(plan, SiriAnswer.no).exercise, isNull);
    expect(finish(plan, SiriAnswer.silence).exercise, isNull);

    final saved = finish(plan, SiriAnswer.yes);
    final exercise = saved.exercise!;
    expect(exercise.name, '水泳');
    expect(exercise.durationMin, 30);
    expect(exercise.loggedAt, loggedAt);
    expect(exercise.netKcal, closeTo(151.2, 0.001));
    expect(exercise.activityId, 'swim_lap');
    expect(saved.food, isNull);
  });

  test('jogging minutes use MET and time', () {
    final plan = planSiriExercise(
      context: context(),
      name: 'Hey Siri、カロナビで、運動にジョギングを30分。',
      quantity: '',
    );

    expect(plan.spoken, 'ジョギング30分の運動でいいですね');
    final exercise = finish(plan, SiriAnswer.yes).exercise!;
    expect(exercise.durationMin, 30);
    expect(exercise.distanceKm, isNull);
    expect(exercise.metValue, 7.5);
    expect(exercise.netKcal, closeTo(204.75, 0.001));
  });

  test('jogging distance uses the published kilometer formula', () {
    final plan = planSiriExercise(
      context: context(),
      name: 'ジョギング',
      quantity: '5km',
    );

    expect(plan.spoken, 'ジョギング5kmの運動でいいですね');
    final exercise = finish(plan, SiriAnswer.yes).exercise!;
    expect(exercise.distanceKm, 5);
    expect(exercise.netKcal, 300);
    expect(exercise.metValue, isNull);
  });

  test('a missing activity and a manual activity are not saved', () {
    final missing = planSiriExercise(
      context: context(),
      name: '宇宙遊泳',
      quantity: '10分',
    );
    final manual = planSiriExercise(
      context: context(),
      name: 'スクワット',
      quantity: '20回',
    );

    expect(missing.status, SiriVoiceStatus.rescue);
    expect(missing.spoken, contains('宇宙遊泳は見つかりません'));
    expect(missing.asksRetry, isTrue);
    expect(manual.spoken, 'スクワットは分で指定してください');
    expect(finish(missing, SiriAnswer.yes).registered, isFalse);
    expect(finish(manual, SiriAnswer.yes).registered, isFalse);
  });

  test('a meal is recognized and repeated before it is saved', () {
    final plan = planSiriUtterance(
      context: context(
        foods: [
          SiriFoodRecord.official(
            foodCode: '11288',
            name: '鶏むね',
            speakName: '鶏むね',
            matchTexts: const ['鶏むね'],
            baseAmount: 100,
            unit: FoodUnitType.g,
            kcalPerBase: 108,
          ),
        ],
      ),
      name: 'Hey Siri、カロナビで、鶏むね100グラム',
      quantity: '',
    );

    expect(plan.spoken, '鶏むね100gの食事でいいですね');
    expect(plan.asksKind, isFalse);
    final saved = finish(plan, SiriAnswer.yes);
    expect(saved.food!.name, '鶏むね');
    expect(saved.food!.consumedAmount, 100);
    expect(saved.exercise, isNull);
  });

  test('an exercise without a marker is repeated as exercise', () {
    final plan = planSiriUtterance(
      context: context(),
      name: 'Hey Siri、カロナビで、ジョギング5キロ',
      quantity: '',
    );

    expect(plan.spoken, 'ジョギング5kmの運動でいいですね');
    final saved = finish(plan, SiriAnswer.yes);
    expect(saved.exercise!.name, 'ジョギング');
    expect(saved.exercise!.distanceKm, 5);
    expect(saved.food, isNull);
  });

  test('words that match neither ask meal or exercise in the repeat', () {
    final plan = planSiriUtterance(
      context: context(),
      name: 'Hey Siri、カロナビで、宇宙遊泳を10分',
      quantity: '',
    );

    expect(plan.asksKind, isTrue);
    expect(plan.spoken, '宇宙遊泳10分は、食事ですか、運動ですか');
    expect(finish(plan, SiriAnswer.yes).registered, isFalse);

    final resolved = resolveSiriSpokenKind(
      context: context(),
      plan: plan,
      kind: SiriSpokenKind.exercise,
    );
    expect(resolved.status, SiriVoiceStatus.rescue);
    expect(resolved.spoken, contains('宇宙遊泳は見つかりません'));
    expect(finish(resolved, SiriAnswer.yes).registered, isFalse);
  });

  test('a word that is both a food and an exercise asks which one', () {
    final both = context(
      foods: [
        SiriFoodRecord.official(
          foodCode: '1',
          name: 'ジョギング',
          speakName: 'ジョギング',
          matchTexts: const ['ジョギング'],
          baseAmount: 100,
          unit: FoodUnitType.g,
          kcalPerBase: 100,
        ),
      ],
    );
    final plan = planSiriUtterance(
      context: both,
      name: 'カロナビで、ジョギングを5km',
      quantity: '',
    );

    expect(plan.spoken, 'ジョギング5kmは、食事ですか、運動ですか');
    expect(finish(plan, SiriAnswer.yes).registered, isFalse);

    final meal = resolveSiriSpokenKind(
      context: both,
      plan: plan,
      kind: SiriSpokenKind.meal,
    );
    expect(meal.spoken, 'ジョギングはgで指定してください');
    expect(finish(meal, SiriAnswer.yes).registered, isFalse);

    final exercise = resolveSiriSpokenKind(
      context: both,
      plan: plan,
      kind: SiriSpokenKind.exercise,
    );
    expect(exercise.spoken, 'ジョギング5kmの運動でいいですね');
    expect(finish(exercise, SiriAnswer.yes).exercise!.distanceKm, 5);
  });

  test('pending json imports one confirmed food and skips another user', () {
    final food = finish(
      planSiriFood(context: context(), name: 'ささみ', quantity: '300g'),
      SiriAnswer.yes,
    ).food!;
    final raw = SiriVoiceCodec.encodePending(ownerUserId: 'user-1', food: food);
    final row = Map<String, Object?>.from(
      (jsonDecode(raw) as List).single as Map,
    );
    final other = Map<String, Object?>.from(row);
    other['ownerUserId'] = 'user-2';
    other['id'] = 'other';

    final imported = SiriVoiceCodec.decodePending(
      raw: jsonEncode([row, other]),
      ownerUserId: 'user-1',
      existingFoodIds: const {},
      existingExerciseIds: const {},
    );

    expect(imported.foods, hasLength(1));
    expect(imported.foods.single.totalKcal, 294);
    expect(imported.acknowledgeIds, [food.id]);

    final again = SiriVoiceCodec.decodePending(
      raw: raw,
      ownerUserId: 'user-1',
      existingFoodIds: {food.id},
      existingExerciseIds: const {},
    );
    expect(again.foods, isEmpty);
    expect(again.acknowledgeIds, [food.id]);
  });

  test(
    'the catalog does not publish a purchase key while official foods are off',
    () {
      final raw = SiriVoiceCodec.encodeCatalog(
        ownerUserId: 'user-1',
        weightKg: 60,
        officialFoodsEnabled: false,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'secret',
        foods: [sasami()],
      );

      expect(raw, contains('"supabaseAnonKey":""'));
      expect(raw, contains('ジョギング'));
      expect(raw, contains('"mealTemplates":[]'));
      expect(raw, contains('"workoutTemplates":[]'));
      expect(raw, isNot(contains('secret')));
    },
  );

  SiriFoodRecord chicken({
    required String code,
    required String speakName,
    required List<String> keys,
    bool isCandidate = false,
    int candidateRank = 100,
    int priority = 100,
    String? officialName,
  }) {
    return SiriFoodRecord.official(
      foodCode: code,
      name: officialName ?? speakName,
      speakName: speakName,
      matchTexts: keys,
      baseAmount: 100,
      unit: FoodUnitType.g,
      kcalPerBase: 108,
      isCandidate: isCandidate,
      candidateRank: candidateRank,
      priority: priority,
    );
  }

  SiriVoiceContext pantry() {
    return context(
      foods: [
        sasami(),
        SiriFoodRecord.official(
          foodCode: '11228',
          name: '若鶏ささみ（焼き）',
          speakName: '若鶏ささみ（焼き）',
          matchTexts: const ['わかどりささみやき'],
          baseAmount: 100,
          unit: FoodUnitType.g,
          kcalPerBase: 125,
        ),
        chicken(
          code: '11220',
          speakName: '若鶏むね（皮なし・生）',
          keys: const ['鶏むね', 'とりむね', 'むね肉', 'わかどりむねかわなまなま'],
          officialName: '若鶏むね（皮なし・生）',
        ),
        chicken(
          code: '11219',
          speakName: '若鶏むね（皮つき・生）',
          keys: const ['鶏むね'],
          isCandidate: true,
          candidateRank: 1,
        ),
        chicken(
          code: '11287',
          speakName: '若鶏むね（皮つき・焼き）',
          keys: const ['鶏むね'],
          isCandidate: true,
          candidateRank: 3,
        ),
        chicken(
          code: '11288',
          speakName: '若鶏むね（皮なし・焼き）',
          keys: const ['鶏むね'],
          isCandidate: true,
          candidateRank: 4,
        ),
        SiriFoodRecord.official(
          foodCode: '01088',
          name: '精白米めし',
          speakName: 'ご飯',
          matchTexts: const ['ご飯', 'ごはん'],
          baseAmount: 100,
          unit: FoodUnitType.g,
          kcalPerBase: 156,
        ),
        SiriFoodRecord.official(
          foodCode: '04046',
          name: '糸引き納豆',
          speakName: '納豆',
          matchTexts: const ['納豆', 'なっとう'],
          baseAmount: 100,
          unit: FoodUnitType.g,
          kcalPerBase: 190,
        ),
      ],
    );
  }

  test('ささみ100g picks the representative raw tenderloin', () {
    final plan = planSiriFood(
      context: pantry(),
      name: 'ささみ100g',
      quantity: '',
    );

    expect(plan.spoken, 'ささみ100gの食事でいいですね');
    expect(finish(plan, SiriAnswer.yes).food!.officialFoodCode, '11227');
  });

  test('鶏むね100g and とりむね150グラム pick skinless raw breast', () {
    final kanji = planSiriFood(
      context: pantry(),
      name: '鶏むね100g',
      quantity: '',
    );
    expect(kanji.spoken, '若鶏むね（皮なし・生）100gの食事でいいですね');
    expect(finish(kanji, SiriAnswer.yes).food!.officialFoodCode, '11220');

    final kana = planSiriFood(
      context: pantry(),
      name: 'とりむね150グラム',
      quantity: '',
    );
    expect(kana.spoken, '若鶏むね（皮なし・生）150gの食事でいいですね');
    expect(finish(kana, SiriAnswer.yes).food!.consumedAmount, 150);
  });

  test('ご飯大盛り asks how many grams and logs the answer', () {
    final plan = planSiriFood(
      context: pantry(),
      name: 'ご飯大盛り',
      quantity: '',
    );

    expect(plan.asksAmount, isTrue);
    expect(plan.spoken, '何gですか？');
    expect(finish(plan, SiriAnswer.yes).registered, isFalse);

    final answered = resolveSiriAmount(
      context: pantry(),
      plan: plan,
      amountText: '250',
    );
    expect(answered.spoken, 'ご飯250gの食事でいいですね');
    expect(finish(answered, SiriAnswer.yes).food!.consumedAmount, 250);
  });

  test('納豆1パック asks how many grams', () {
    final plan = planSiriFood(
      context: pantry(),
      name: '納豆1パック',
      quantity: '',
    );

    expect(plan.asksAmount, isTrue);
    expect(plan.spoken, '何gですか？');
    final answered = resolveSiriAmount(
      context: pantry(),
      plan: plan,
      amountText: '45g',
    );
    expect(answered.spoken, '納豆45gの食事でいいですね');
  });

  test('プロテイン with no hit asks to retry or open the app', () {
    final plan = planSiriFood(
      context: pantry(),
      name: 'プロテイン',
      quantity: '30g',
    );

    expect(plan.status, SiriVoiceStatus.rescue);
    expect(plan.asksRetry, isTrue);
    expect(plan.searchQuery, 'プロテイン');
    expect(plan.spoken, contains('アプリで検索します'));
    expect(finish(plan, SiriAnswer.yes).registered, isFalse);
  });

  test('walking 30 minutes and strength training 20 minutes are logged', () {
    final walk = planSiriExercise(
      context: context(),
      name: 'ウォーキング30分',
      quantity: '',
    );
    expect(walk.spoken, 'ウォーキング30分の運動でいいですね');
    final walked = finish(walk, SiriAnswer.yes).exercise!;
    expect(walked.activityId, 'walk_brisk');
    expect(walked.durationMin, 30);
    expect(walked.distanceKm, isNull);
    expect(walked.netKcal, closeTo(88.2, 0.001));

    final weights = planSiriExercise(
      context: context(),
      name: '筋トレ20分',
      quantity: '',
    );
    expect(weights.spoken, 'ウェイトトレーニング20分の運動でいいですね');
    final lifted = finish(weights, SiriAnswer.yes).exercise!;
    expect(lifted.activityId, 'weight_training');
    expect(lifted.durationMin, 20);
    expect(lifted.netKcal, closeTo(52.5, 0.001));
  });

  test('散歩した asks how many minutes', () {
    final plan = planSiriExercise(
      context: context(),
      name: '散歩した',
      quantity: '',
    );

    expect(plan.asksAmount, isTrue);
    expect(plan.spoken, '何分ですか？');
    final answered = resolveSiriAmount(
      context: context(),
      plan: plan,
      amountText: '15',
    );
    expect(answered.spoken, 'ウォーキング15分の運動でいいですね');
    expect(finish(answered, SiriAnswer.yes).exercise!.activityId, 'walk_brisk');
  });

  test('a meal template name logs that template', () {
    final breakfast = SiriMealTemplate(
      id: 'meal-1',
      speakName: '朝ごはん',
      keys: const ['朝ごはん', 'あさごはん'],
      items: [
        SiriTemplateFood(food: sasami(), consumedAmount: 80),
      ],
    );
    final plan = planSiriUtterance(
      context: context(foods: [sasami()], mealTemplates: [breakfast]),
      name: 'Hey Siri、カロナビで、朝ごはん',
      quantity: '',
    );

    expect(plan.spoken, '朝ごはんのテンプレートでいいですね');
    final saved = finish(plan, SiriAnswer.yes);
    expect(saved.foods, hasLength(1));
    expect(saved.foods.single.consumedAmount, 80);
    expect(saved.foods.single.officialFoodCode, '11227');
  });

  test('a workout template name logs that template', () {
    final routine = SiriWorkoutTemplate(
      id: 'work-1',
      speakName: '朝の運動',
      keys: const ['朝の運動', 'あさのうんどう'],
      exercises: const [
        SiriWorkoutTemplateExercise(activityId: 'swim_lap', minutes: 20),
      ],
    );
    final plan = planSiriExercise(
      context: context(workoutTemplates: [routine]),
      name: '朝の運動',
      quantity: '',
    );

    expect(plan.spoken, '朝の運動のテンプレートでいいですね');
    final saved = finish(plan, SiriAnswer.yes);
    expect(saved.exercises, hasLength(1));
    expect(saved.exercises.single.activityId, 'swim_lap');
    expect(saved.exercises.single.durationMin, 20);
  });
}
