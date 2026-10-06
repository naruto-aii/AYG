import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/services/siri_speech_repair.dart';
import 'package:ayg/services/siri_voice_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SiriFoodRecord food({
    required String code,
    required String speakName,
    required List<String> keys,
  }) {
    return SiriFoodRecord.official(
      foodCode: code,
      name: speakName,
      speakName: speakName,
      matchTexts: keys,
      baseAmount: 100,
      unit: FoodUnitType.g,
      kcalPerBase: 100,
    );
  }

  SiriVoiceContext context(List<SiriFoodRecord> foods) {
    return SiriVoiceContext(
      paid: true,
      ownerUserId: 'user-1',
      weightKg: 60,
      foods: foods,
    );
  }

  test('a restart that begins with the earlier fragment keeps the later word', () {
    expect(
      siriSpeechInterpretations('ささ、あー、ささみ'),
      ['ささみ', 'ささささみ'],
    );
  });

  test('fragments split by a filler are joined', () {
    expect(siriSpeechInterpretations('ささ、あー、み'), ['ささみ']);
  });

  test('a quantity keeps the same filler repair and becomes digits', () {
    expect(siriSpeechInterpretations('ひゃく、えー、グラム'), ['ひゃくグラム']);
    expect(foldSiriSpokenQuantities('ひゃくグラム'), '100グラム');
  });

  test('hiragana inside a food name is not treated as a filler', () {
    expect(siriSpeechInterpretations('あさり'), ['あさり']);
    expect(siriSpeechInterpretations('あ、さり'), ['さり']);
  });

  test('filler variants with long vowels and small kana are removed', () {
    expect(
      siriSpeechInterpretations('たまご、えぇ、えっと、たまご'),
      ['たまご', 'たまごたまご'],
    );
    expect(
      siriSpeechInterpretations('ごはん、んー、なんか、ごはん'),
      ['ごはん', 'ごはんごはん'],
    );
  });

  test('the repaired food name is what gets matched', () {
    final sasami = food(
      code: '11227',
      speakName: 'ささみ',
      keys: const ['ささみ'],
    );
    final restarted = planSiriFood(
      context: context([sasami]),
      name: 'ささ、あー、ささみ',
      quantity: '300g',
    );
    expect(restarted.spoken, 'ささみ300gを登録しました');

    final joined = planSiriFood(
      context: context([sasami]),
      name: 'ささ、あー、み',
      quantity: '100g',
    );
    expect(joined.spoken, 'ささみ100gを登録しました');

    final spokenAmount = planSiriFood(
      context: context([sasami]),
      name: 'ささみをひゃく、えー、グラム',
      quantity: '',
    );
    expect(spokenAmount.spoken, 'ささみ100gを登録しました');
  });

  test('tied interpretations become a choice', () {
    final plan = planSiriFood(
      context: context([
        food(code: '11227', speakName: 'ささみ', keys: const ['ささみ']),
        food(
          code: '99999',
          speakName: 'ささささみ',
          keys: const ['ささささみ'],
        ),
      ]),
      name: 'ささ、あー、ささみ',
      quantity: '100g',
    );

    expect(plan.asksChoice, isTrue);
    expect(plan.choices.map((choice) => choice.title), ['ささみ', 'ささささみ']);
  });

  test('exercise names drop fillers and restarts too', () {
    final filled = planSiriExercise(
      context: context(const []),
      name: 'ジョギング、えー、30分',
      quantity: '',
    );
    expect(filled.spoken, 'ジョギング30分を登録しました');

    final restarted = planSiriExercise(
      context: context(const []),
      name: 'ジョ、ジョギングを30分',
      quantity: '',
    );
    expect(restarted.spoken, 'ジョギング30分を登録しました');
  });
}
