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
  }) {
    return SiriVoiceContext(
      paid: paid,
      ownerUserId: 'user-1',
      weightKg: weightKg,
      foods: foods ?? [sasami()],
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
    expect(plan.spoken, 'ささみを300gですね');

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
      name: '食事にささみを300g',
      quantity: '',
    );

    expect(plan.spoken, 'ささみを300gですね');
  });

  test('a missing food is not saved even after yes', () {
    final plan = planSiriFood(
      context: context(),
      name: 'うなぎ',
      quantity: '100g',
    );

    expect(plan.asksConfirmation, isFalse);
    expect(plan.spoken, 'うなぎは見つかりません');
    expect(finish(plan, SiriAnswer.yes).food, isNull);
  });

  test('a partial food name is not treated as a match', () {
    final plan = planSiriFood(context: context(), name: 'ささ', quantity: '100g');

    expect(plan.status, SiriVoiceStatus.notFound);
    expect(finish(plan, SiriAnswer.yes).registered, isFalse);
  });

  test('two foods with the same name are not guessed', () {
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

    expect(plan.spoken, 'ささみはひとつに決まりません');
    expect(finish(plan, SiriAnswer.yes).food, isNull);
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
      name: '運動に水泳を30分',
      quantity: '',
    );

    expect(plan.spoken, '水泳を30分ですね');
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

  test('jogging minutes are not converted into a calorie', () {
    final plan = planSiriExercise(
      context: context(),
      name: 'ジョギング',
      quantity: '30分',
    );

    expect(plan.asksConfirmation, isFalse);
    expect(plan.spoken, 'ジョギングはkmで指定してください');
    expect(finish(plan, SiriAnswer.yes).exercise, isNull);
  });

  test('jogging distance uses the published kilometer formula', () {
    final plan = planSiriExercise(
      context: context(),
      name: 'ジョギング',
      quantity: '5km',
    );

    expect(plan.spoken, 'ジョギングを5kmですね');
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

    expect(missing.spoken, '宇宙遊泳は見つかりません');
    expect(manual.spoken, 'スクワットは手入力の種目です');
    expect(finish(missing, SiriAnswer.yes).registered, isFalse);
    expect(finish(manual, SiriAnswer.yes).registered, isFalse);
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
      expect(raw, isNot(contains('secret')));
      expect(raw, isNot(contains('template')));
    },
  );
}
