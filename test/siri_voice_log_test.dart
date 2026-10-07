import 'dart:convert';

import 'package:ayg/models/food_entry_source.dart';
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
    List<SiriFoodRecord> remoteOfficial = const [],
    List<SiriFoodRecord> remotePublic = const [],
    bool remoteUnavailable = false,
    String? lastLogLabel,
  }) {
    return SiriVoiceContext(
      paid: paid,
      ownerUserId: 'user-1',
      weightKg: weightKg,
      foods: foods ?? [sasami()],
      mealTemplates: mealTemplates,
      workoutTemplates: workoutTemplates,
      remoteOfficial: remoteOfficial,
      remotePublic: remotePublic,
      remoteUnavailable: remoteUnavailable,
      lastLogLabel: lastLogLabel,
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

  test('a confident food is registered and reported without asking', () {
    final plan = planSiriFood(
      context: context(),
      name: 'ささみ',
      quantity: '300g',
    );

    expect(plan.confident, isTrue);
    expect(plan.asksConfirmation, isFalse);
    expect(plan.spoken, 'ささみ300gを登録しました');

    final saved = finish(plan, SiriAnswer.yes);
    expect(saved.status, SiriVoiceStatus.registered);
    expect(saved.spoken, 'ささみ300gを登録しました');
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

    expect(plan.spoken, 'ささみ300gを登録しました');
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
      expect(noKind.spoken, 'ジョギング30分を登録しました');
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
    expect(chosen.spoken, 'ささみ100gを登録しました');
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

    expect(food.spoken, '音声登録はβ版です。カロナビ+で先に使えます。');
    expect(exercise.spoken, '音声登録はβ版です。カロナビ+で先に使えます。');
    expect(finish(food, SiriAnswer.yes).registered, isFalse);
    expect(finish(exercise, SiriAnswer.yes).registered, isFalse);
  });

  test('a confident exercise is registered and reported without asking', () {
    final plan = planSiriExercise(
      context: context(),
      name: 'カロナビで、運動に水泳を30分',
      quantity: '',
    );

    expect(plan.confident, isTrue);
    expect(plan.asksConfirmation, isFalse);
    expect(plan.spoken, '水泳30分を登録しました');
    expect(finish(plan, SiriAnswer.no).exercise!.durationMin, 30);
    expect(finish(plan, SiriAnswer.silence).exercise!.durationMin, 30);

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

    expect(plan.spoken, 'ジョギング30分を登録しました');
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

    expect(plan.spoken, 'ジョギング5kmを登録しました');
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

    expect(plan.spoken, '鶏むね100gを登録しました');
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

    expect(plan.spoken, 'ジョギング5kmを登録しました');
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
    expect(exercise.spoken, 'ジョギング5kmを登録しました');
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

    expect(plan.spoken, 'ささみ100gを登録しました');
    expect(finish(plan, SiriAnswer.yes).food!.officialFoodCode, '11227');
  });

  test('鶏むね100g and とりむね150グラム pick skinless raw breast', () {
    final kanji = planSiriFood(
      context: pantry(),
      name: '鶏むね100g',
      quantity: '',
    );
    expect(kanji.spoken, '若鶏むね（皮なし・生）100gを登録しました');
    expect(finish(kanji, SiriAnswer.yes).food!.officialFoodCode, '11220');

    final kana = planSiriFood(
      context: pantry(),
      name: 'とりむね150グラム',
      quantity: '',
    );
    expect(kana.spoken, '若鶏むね（皮なし・生）150gを登録しました');
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
    expect(answered.spoken, 'ご飯250gを登録しました');
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
    expect(answered.spoken, '納豆45gを登録しました');
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
    expect(walk.spoken, 'ウォーキング30分を登録しました');
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
    expect(weights.spoken, 'ウェイトトレーニング20分を登録しました');
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
    expect(answered.spoken, 'ウォーキング15分を登録しました');
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

    expect(plan.spoken, '朝ごはんを登録しました');
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

    expect(plan.spoken, '朝の運動を登録しました');
    final saved = finish(plan, SiriAnswer.yes);
    expect(saved.exercises, hasLength(1));
    expect(saved.exercises.single.activityId, 'swim_lap');
    expect(saved.exercises.single.durationMin, 20);
  });

  SiriFoodRecord remoteRice() {
    return SiriFoodRecord.official(
      foodCode: '01088',
      name: '精白米',
      speakName: '精白米（うるち米・水稲めし）',
      matchTexts: const ['精白米'],
      baseAmount: 100,
      unit: FoodUnitType.g,
      kcalPerBase: 156,
      searchRank: 0,
      searchAliasMatched: true,
    );
  }

  SiriFoodRecord remotePublicChicken() {
    return const SiriFoodRecord(
      id: 'owner-2:food-9',
      speakName: '自家製サラダチキン',
      keys: ['自家製さらだちきん'],
      baseAmount: 100,
      unit: FoodUnitType.g,
      source: FoodEntrySource.savedFood,
      savedFoodId: 'food-9',
      sourceOwnerUserId: 'owner-2',
      kcalPerBase: 110,
      searchRank: 0,
    );
  }

  test('official search is used before a public food', () {
    final plan = planSiriFood(
      context: context(
        foods: const [],
        remoteOfficial: [remoteRice()],
        remotePublic: [remotePublicChicken()],
      ),
      name: 'ご飯',
      quantity: '',
    );

    expect(plan.food?.officialFoodCode, '01088');
    expect(plan.asksAmount, isTrue);
    expect(plan.spoken, '何gですか？');
  });

  test('a public food is used when the composition table misses', () {
    final plan = planSiriFood(
      context: context(
        foods: const [],
        remotePublic: [remotePublicChicken()],
      ),
      name: 'サラダチキン',
      quantity: '80g',
    );

    expect(plan.food?.savedFoodId, 'food-9');
    expect(plan.food?.sourceOwnerUserId, 'owner-2');
    expect(plan.spoken, '自家製サラダチキン80gを登録しました');
  });

  test('a network failure keeps saved foods and skips remote rows', () {
    final plan = planSiriFood(
      context: context(
        foods: const [],
        remoteOfficial: [remoteRice()],
        remotePublic: [remotePublicChicken()],
        remoteUnavailable: true,
      ),
      name: 'ご飯',
      quantity: '100g',
    );

    expect(plan.status, SiriVoiceStatus.rescue);
    expect(plan.spoken, contains('アプリで検索します'));
  });

  test('an empty access token does not invent a public food', () {
    final plan = planSiriFood(
      context: context(foods: const [], remotePublic: const []),
      name: 'サラダチキン',
      quantity: '100g',
    );

    expect(plan.status, SiriVoiceStatus.rescue);
  });

  test('the last registration can be undone in one phrase', () {
    final remembered = context(lastLogLabel: 'ささみ100g');
    for (final phrase in [
      'さっきの登録を取り消して',
      '今登録したやつ消して',
      '取り消して',
      'Hey Siri、カロナビで、さっきの登録を取り消して',
    ]) {
      final plan = planSiriUtterance(
        context: remembered,
        name: phrase,
        quantity: '',
      );
      expect(plan.status, SiriVoiceStatus.undone, reason: phrase);
      expect(plan.spoken, 'ささみ100gの登録を取り消しました', reason: phrase);
      expect(plan.food, isNull, reason: phrase);
    }

    final exercise = planSiriExercise(
      context: context(lastLogLabel: 'ジョギング30分'),
      name: '今登録したやつ消して',
      quantity: '',
    );
    expect(exercise.status, SiriVoiceStatus.undone);
    expect(exercise.spoken, 'ジョギング30分の登録を取り消しました');

    final missing = planSiriFood(
      context: context(),
      name: 'さっきの登録を取り消して',
      quantity: '',
    );
    expect(missing.status, SiriVoiceStatus.notFound);
    expect(missing.spoken, '取り消す登録がありません');

    final today = planSiriFood(
      context: remembered,
      name: '今日の牛肉消して',
      quantity: '',
    );
    expect(today.status, isNot(SiriVoiceStatus.undone));
  });

  test('an undo marker names the registration to delete', () {
    final imported = SiriVoiceCodec.decodePending(
      raw: jsonEncode([
        {
          'kind': 'undo',
          'id': 'marker-1',
          'ownerUserId': 'user-1',
          'targetId': 'food-9',
        },
        {
          'kind': 'undo',
          'id': 'marker-2',
          'ownerUserId': 'user-2',
          'targetId': 'other',
        },
      ]),
      ownerUserId: 'user-1',
      existingFoodIds: const {},
      existingExerciseIds: const {},
    );

    expect(imported.undoIds, ['food-9']);
    expect(imported.acknowledgeIds, ['marker-1']);
    expect(imported.foods, isEmpty);
    expect(imported.exercises, isEmpty);
  });
}
