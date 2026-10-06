import 'dart:convert';
import 'dart:io';

import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/services/food_name_traits.dart';
import 'package:ayg/services/siri_voice_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = _loadCatalog();

  SiriVoiceContext context() {
    return SiriVoiceContext(
      paid: true,
      ownerUserId: 'user-1',
      foods: catalog.all,
      searchFoods: catalog.search,
    );
  }

  test('cook and cut come from the food name, for every official food', () {
    final rows = File('test/fixtures/official_food_display.tsv')
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty)
        .map(_NameRow.parse)
        .toList();
    expect(rows, hasLength(2538));
    var cuts = 0;
    var cooks = 0;
    for (final row in rows) {
      final traits = traitsFromFoodName(row.display, foodCode: row.code);
      expect(traits.kind, isNotNull, reason: row.display);
      if (row.group == '07') {
        expect(traits.cut, isNot('momo'), reason: row.display);
      }
      if (row.group == '11' && row.display.contains('もも')) {
        expect(traits.cut, 'momo', reason: row.display);
      }
      if (row.group == '11' &&
          (row.display.contains('むね') || row.display.contains('胸'))) {
        expect(traits.cut, 'mune', reason: row.display);
      }
      if (row.group == '11' && row.display.contains('ささみ')) {
        expect(traits.cut, 'sasami', reason: row.display);
      }
      if (traits.cut != null) {
        cuts += 1;
      }
      if (traits.cook != null) {
        cooks += 1;
      }
      if (row.display.contains('（生）') || row.display.contains('・生）')) {
        if (!row.display.contains('揚') && !row.display.contains('焼')) {
          expect(traits.cook, 'raw', reason: row.display);
        }
      }
      if (row.display.contains('（焼き）') || row.display.contains('・焼き）')) {
        expect(traits.cook, 'grilled', reason: row.display);
      }
      if (row.display.contains('（ゆで）') || row.display.contains('・ゆで）')) {
        expect(traits.cook, 'boiled', reason: row.display);
      }
    }
    expect(cuts, greaterThan(200));
    expect(cooks, greaterThan(800));
  });

  test('spoken answers accept everyday words', () {
    expect(parseSpokenFoodReply('もも').traits.cut, 'momo');
    expect(parseSpokenFoodReply('焼いたやつ').traits.cook, 'grilled');
    expect(parseSpokenFoodReply('ゆでた').traits.cook, 'boiled');
    expect(parseSpokenFoodReply('揚げたやつ').traits.cook, 'fried');
    expect(parseSpokenFoodReply('生').traits.cook, 'raw');
    expect(parseSpokenFoodReply('普通の').unknown, isTrue);
    expect(parseSpokenFoodReply('わからない').unknown, isTrue);
    expect(parseSpokenFoodReply('何でもいい').unknown, isTrue);
    expect(parseSpokenFoodReply('やめる').cancel, isTrue);
    expect(parseSpokenFoodReply('キャンセル').cancel, isTrue);
    expect(parseSpokenFoodReply('さけ').traits.kind, 'さけ');
  });

  test('coarse speech reaches a food without reading the whole list', () {
    final cases = [
      _Case('牛肉', const ['もも', '焼き'], '11250', question: 'どの部位ですか？'),
      _Case('豚肉', const ['ばら', 'わからない'], '11129', question: 'どの部位ですか？'),
      _Case('鶏肉', const ['むね', '生'], '11220', question: 'どの部位ですか？'),
      _Case('魚', const ['さけ', '生'], '10134', question: '何の魚ですか？'),
      _Case('さけ', const ['生'], '10134', question: '生、焼き、ゆで、揚げのどれですか？'),
      _Case('白菜', const ['生'], '06233', question: '生かゆでですか？'),
      _Case('牛肉', const ['わからない'], '11004', question: 'どの部位ですか？'),
    ];
    final rounds = <int>[];
    for (final item in cases) {
      final run = _talk(context(), item.utterance, item.answers);
      expect(run.plan.asksNarrow, isFalse, reason: run.lines.join('\n'));
      expect(
        run.plan.food?.officialFoodCode,
        item.code,
        reason: run.lines.join('\n'),
      );
      expect(run.lines[1], 'S: ${item.question}', reason: run.lines.join('\n'));
      expect(run.lines.join('\n'), isNot(contains('次のどれですか')));
      rounds.add(run.roundsToFood);
    }
    final mean = rounds.reduce((a, b) => a + b) / rounds.length;
    final maxRound = rounds.reduce((a, b) => a > b ? a : b);
    expect(mean, lessThan(3.5));
    expect(maxRound, lessThanOrEqualTo(3));
    // 報告用。平均と最大はテストが落とすので、ここでも残す。
    expect(rounds, [3, 3, 3, 3, 2, 2, 2]);
    expect(mean, closeTo(2.57, 0.01));
  });

  test('a detailed phrase skips the questions and keeps the amount', () {
    final cases = [
      _Case('牛ももの焼き200g', const [], '11250', amount: 200),
      _Case('鶏むねの生100g', const [], '11220', amount: 100),
      _Case('ささみの生100g', const [], '11227', amount: 100),
      _Case('しろさけの焼き100g', const [], '10136', amount: 100),
      _Case('はくさいのゆで100g', const [], '06234', amount: 100),
      _Case('牛ももの焼き', const ['200g'], '11250', amount: 200),
    ];
    final rounds = <int>[];
    for (final item in cases) {
      final run = _talk(context(), item.utterance, [...item.answers]);
      expect(
        run.plan.food?.officialFoodCode,
        item.code,
        reason: run.lines.join('\n'),
      );
      expect(run.plan.asksConfirmation, isTrue, reason: run.lines.join('\n'));
      expect(
        run.plan.quantity?.amount,
        item.amount,
        reason: run.lines.join('\n'),
      );
      expect(run.roundsToFood, 1, reason: run.lines.join('\n'));
      rounds.add(run.roundsToFood);
      final saved = commitSiriVoice(
        plan: run.plan,
        answer: SiriAnswer.yes,
        loggedAt: DateTime(2026, 10, 6, 12),
        ownerUserId: 'user-1',
        weightKg: 60,
        newId: () => 'id-1',
      );
      expect(saved.status, SiriVoiceStatus.registered);
      expect(saved.food!.officialFoodCode, item.code);
      expect(saved.food!.consumedAmount, item.amount);
    }
    expect(rounds, everyElement(1));
  });

  test('cancel ends the dialog', () {
    final run = _talk(context(), '牛肉', const ['キャンセル']);
    expect(run.plan.status, SiriVoiceStatus.cancelled);
    expect(run.plan.spoken, '登録しません');
    expect(run.plan.food, isNull);
    final saved = commitSiriVoice(
      plan: run.plan,
      answer: SiriAnswer.yes,
      loggedAt: DateTime(2026, 10, 6, 12),
      ownerUserId: 'user-1',
      weightKg: 60,
      newId: () => 'id-1',
    );
    expect(saved.registered, isFalse);
  });

  test('two foods with the same name are still read aloud', () {
    final plan = planSiriFood(
      context: SiriVoiceContext(
        paid: true,
        ownerUserId: 'user-1',
        foods: [
          _record('11227', 'ささみ', '若鶏ささみ（生）'),
          _record('99999', 'ささみ', '別のささみ'),
        ],
      ),
      name: 'ささみ',
      quantity: '100g',
    );
    expect(plan.asksChoice, isTrue);
    expect(plan.choices, hasLength(2));
    expect(plan.spoken, contains('どれですか'));
  });
}

class _Case {
  const _Case(
    this.utterance,
    this.answers,
    this.code, {
    this.question,
    this.amount,
  });

  final String utterance;
  final List<String> answers;
  final String code;
  final String? question;
  final double? amount;
}

class _Talk {
  const _Talk(this.roundsToFood, this.plan, this.lines);

  final int roundsToFood;
  final SiriVoicePlan plan;
  final List<String> lines;
}

_Talk _talk(SiriVoiceContext context, String utterance, List<String> answers) {
  final pending = [...answers];
  var plan = planSiriFood(context: context, name: utterance, quantity: '');
  final lines = <String>['U: $utterance', 'S: ${plan.spoken}'];
  var roundsToFood = 1;
  var guard = 0;
  while (guard++ < 8 && plan.food == null) {
    if (plan.asksNarrow) {
      expect(pending, isNotEmpty, reason: lines.join('\n'));
      final answer = pending.removeAt(0);
      plan = resolveSiriFoodNarrow(
        context: context,
        plan: plan,
        answer: answer,
      );
      lines.add('U: $answer');
      lines.add('S: ${plan.spoken}');
      roundsToFood += 1;
      continue;
    }
    if (plan.asksChoice) {
      expect(pending, isNotEmpty, reason: lines.join('\n'));
      final answer = pending.removeAt(0);
      plan = resolveSiriChoice(context: context, plan: plan, choiceId: answer);
      lines.add('U: $answer');
      lines.add('S: ${plan.spoken}');
      roundsToFood += 1;
      continue;
    }
    break;
  }
  while (plan.asksAmount && pending.isNotEmpty) {
    final answer = pending.removeAt(0);
    plan = resolveSiriAmount(context: context, plan: plan, amountText: answer);
    lines.add('U: $answer');
    lines.add('S: ${plan.spoken}');
  }
  return _Talk(roundsToFood, plan, lines);
}

class _Catalog {
  _Catalog(this.byQuery, this.all);

  final Map<String, List<SiriFoodRecord>> byQuery;
  final List<SiriFoodRecord> all;

  List<SiriFoodRecord> search(String query) {
    return byQuery[query] ?? const [];
  }
}

_Catalog _loadCatalog() {
  final raw =
      jsonDecode(
            File('test/fixtures/siri_narrow_search.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final byQuery = <String, List<SiriFoodRecord>>{};
  final all = <String, SiriFoodRecord>{};
  for (final entry in raw.entries) {
    final rows = (entry.value as List<dynamic>).cast<Map<String, dynamic>>();
    final foods = <SiriFoodRecord>[];
    for (final row in rows) {
      final food = _record(
        row['food_code'] as String,
        row['display_name'] as String,
        row['name'] as String,
        searchRank: row['match_rank'] as int?,
        isCandidate: row['is_candidate'] as bool? ?? false,
        candidateRank: row['candidate_rank'] as int? ?? 100,
      );
      foods.add(food);
      all[food.id] = food;
    }
    byQuery[entry.key] = foods;
  }
  return _Catalog(byQuery, all.values.toList());
}

SiriFoodRecord _record(
  String code,
  String display,
  String name, {
  int? searchRank,
  bool isCandidate = false,
  int candidateRank = 100,
}) {
  return SiriFoodRecord.official(
    foodCode: code,
    name: name,
    speakName: display,
    matchTexts: [display],
    baseAmount: 100,
    unit: FoodUnitType.g,
    kcalPerBase: 100,
    searchRank: searchRank,
    isCandidate: isCandidate,
    candidateRank: candidateRank,
  );
}

class _NameRow {
  const _NameRow(this.code, this.group, this.display);

  final String code;
  final String group;
  final String display;

  static _NameRow parse(String line) {
    final parts = line.split('\t');
    return _NameRow(parts[0], parts[1], parts.sublist(2).join('\t'));
  }
}
