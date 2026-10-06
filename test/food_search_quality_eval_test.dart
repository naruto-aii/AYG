import 'dart:io';

import 'package:ayg/data/met_activity_catalog.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/official_food.dart';
import 'package:ayg/services/official_food_ranker.dart';
import 'package:ayg/services/official_food_spoken.dart';
import 'package:ayg/services/siri_name_match.dart';
import 'package:ayg/services/siri_speech_repair.dart';
import 'package:ayg/services/siri_voice_log.dart';
import 'package:ayg/utils/food_search_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

/// 口語・略称・誤認識・フィラー・量・運動名の名寄せ評価。
///
/// 改修前は食品成分表のラベル別名と、すでに入っている「とりむね」だけ。
/// 改修後は口語辞書、手動の別名、正式名から作った読み、言い間違いを足す。
void main() {
  const ranker = OfficialFoodRanker();

  late List<OfficialFoodCatalogItem> beforeCatalog;
  late List<OfficialFoodCatalogItem> afterCatalog;
  late List<_Query> spoken;
  late List<_Query> labelRegression;

  setUpAll(() {
    final labels = _readRepo('supabase/migrations/20260929180000_official_food_labels.sql');
    final csv = _readRepo('supabase/seed/official_food_aliases.csv');
    final foods = _parseDisplays(labels);
    final labelAliases = _parseLabelAliases(labels);
    final csvAliases = _parseCsv(csv);

    beforeCatalog = _catalog(
      foods,
      [
        ...labelAliases,
        ..._siriAliases(),
      ],
    );
    afterCatalog = _catalog(
      foods,
      [
        ...labelAliases,
        ..._siriAliases(),
        ...csvAliases,
        ...manualSpokenAliases.map((item) => item.toAliasRow()),
        ..._generated(foods),
      ],
    );

    final facts = <String, List<_Fact>>{};
    void addFact(_AliasRow row) {
      for (final surface in [row.alias, row.reading]) {
        final text = surface.trim();
        if (text.runes.length < 2) {
          continue;
        }
        facts.putIfAbsent(text, () => []).add(
          _Fact(
            row.foodCode,
            row.isCandidate,
            row.candidateRank,
            row.priority,
          ),
        );
      }
    }

    for (final row in [...csvAliases, ...manualSpokenAliases.map((item) => item.toAliasRow())]) {
      addFact(row);
    }
    spoken = [
      for (final entry in facts.entries)
        _Query(entry.key, _best(entry.value), entry.value.map((fact) => fact.code).toSet(), '辞書'),
      ..._handQueries(),
    ];

    final labelFacts = <String, List<_Fact>>{};
    for (final row in labelAliases.where((row) => !row.isGroup)) {
      final text = row.alias.trim();
      if (text.runes.length < 2) {
        continue;
      }
      labelFacts.putIfAbsent(text, () => []).add(
        _Fact(row.foodCode, row.isCandidate, row.candidateRank, row.priority),
      );
    }
    labelRegression = [
      for (final entry in labelFacts.entries)
        _Query(entry.key, _best(entry.value), entry.value.map((fact) => fact.code).toSet(), 'ラベル'),
    ];
  });

  test('spoken food names improve and do not lose a correct top hit', () {
    final before = _scoreFoods(ranker, beforeCatalog, spoken, fuzzy: false);
    final after = _scoreFoods(ranker, afterCatalog, spoken, fuzzy: true);
    final lost = _lostTop1(ranker, beforeCatalog, afterCatalog, spoken);

    final report = StringBuffer()
      ..writeln('spoken ${spoken.length}')
      ..writeln('before top1 ${before.top1}/${before.total} ${_pct(before.top1, before.total)}')
      ..writeln('before top3 ${before.top3}/${before.total} ${_pct(before.top3, before.total)}')
      ..writeln('after top1 ${after.top1}/${after.total} ${_pct(after.top1, after.total)}')
      ..writeln('after top3 ${after.top3}/${after.total} ${_pct(after.top3, after.total)}')
      ..writeln('lost ${lost.length}')
      ..writeln(after.misses.take(40).join('\n'));
    File('/tmp/food_eval_spoken.txt').writeAsStringSync(report.toString());
    // ignore: avoid_print
    print(report);

    expect(after.top1, greaterThanOrEqualTo(before.top1));
    expect(after.top3, greaterThanOrEqualTo(before.top3));
    expect(lost, isEmpty, reason: lost.take(20).join('\n'));
    expect(after.misses, isEmpty, reason: after.misses.take(30).join('\n'));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('label aliases that already hit stay on the same food', () {
    final before = _scoreFoods(ranker, beforeCatalog, labelRegression, fuzzy: false);
    final after = _scoreFoods(ranker, afterCatalog, labelRegression, fuzzy: true);
    final lost = _lostTop1(ranker, beforeCatalog, afterCatalog, labelRegression);
    final report = StringBuffer()
      ..writeln('labels ${labelRegression.length}')
      ..writeln('before top1 ${before.top1}/${before.total} ${_pct(before.top1, before.total)}')
      ..writeln('before top3 ${before.top3}/${before.total} ${_pct(before.top3, before.total)}')
      ..writeln('after top1 ${after.top1}/${after.total} ${_pct(after.top1, after.total)}')
      ..writeln('after top3 ${after.top3}/${after.total} ${_pct(after.top3, after.total)}')
      ..writeln('lost ${lost.length}')
      ..writeln(lost.take(30).join('\n'));
    File('/tmp/food_eval_labels.txt').writeAsStringSync(report.toString());
    // ignore: avoid_print
    print(report);
    expect(lost, isEmpty, reason: lost.take(20).join('\n'));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('fillers, quantities, and exercise names resolve', () {
    final food = _scoreUtterances(ranker, beforeCatalog, afterCatalog);
    final exercise = _scoreExercises();
    final report = StringBuffer()
      ..writeln('utterances ${food.total}')
      ..writeln('utterance before top1 ${food.beforeTop1}/${food.total} ${_pct(food.beforeTop1, food.total)}')
      ..writeln('utterance before top3 ${food.beforeTop3}/${food.total} ${_pct(food.beforeTop3, food.total)}')
      ..writeln('utterance after top1 ${food.afterTop1}/${food.total} ${_pct(food.afterTop1, food.total)}')
      ..writeln('utterance after top3 ${food.afterTop3}/${food.total} ${_pct(food.afterTop3, food.total)}')
      ..writeln(food.misses.join('\n'))
      ..writeln('exercises ${exercise.total}')
      ..writeln('exercise before top1 ${exercise.beforeTop1}/${exercise.total} ${_pct(exercise.beforeTop1, exercise.total)}')
      ..writeln('exercise after top1 ${exercise.afterTop1}/${exercise.total} ${_pct(exercise.afterTop1, exercise.total)}')
      ..writeln(exercise.misses.join('\n'));
    File('/tmp/food_eval_speech.txt').writeAsStringSync(report.toString());
    // ignore: avoid_print
    print(report);
    expect(food.afterTop1, food.total, reason: food.misses.join('\n'));
    expect(food.afterTop3, food.total);
    expect(exercise.afterTop1, exercise.total, reason: exercise.misses.join('\n'));
  });

  test('migration keeps the shared search and the spoken aliases', () {
    final sql = _readRepo('supabase/migrations/20261006180000_food_search_readings.sql');
    final down = _readRepo('supabase/rollback/20261006180000_food_search_readings_down.sql');
    expect(sql, contains('search_official_foods_strict'));
    expect(sql, contains('search_public_foods'));
    expect(sql, contains('味噌汁'));
    expect(sql, contains('さささみ'));
    expect(sql, contains('order by 31'));
    expect(sql, contains('grant execute on function public.search_official_foods(text, integer) to anon'));
    expect(sql, contains('grant execute on function public.search_public_foods(text, integer) to authenticated'));
    expect(down, contains('search_official_foods_strict'));
    expect(down, contains('search_public_foods'));
  });
}

class _Fact {
  const _Fact(this.code, this.isCandidate, this.candidateRank, this.priority);

  final String code;
  final bool isCandidate;
  final int? candidateRank;
  final int priority;
}

class _Query {
  const _Query(this.text, this.top1, this.top3, this.bucket);

  final String text;
  final String top1;
  final Set<String> top3;
  final String bucket;
}

class _AliasRow {
  const _AliasRow({
    required this.foodCode,
    required this.alias,
    required this.reading,
    required this.normalized,
    required this.priority,
    required this.isCandidate,
    this.candidateRank,
    this.isGroup = false,
  });

  final String foodCode;
  final String alias;
  final String reading;
  final String normalized;
  final int priority;
  final bool isCandidate;
  final int? candidateRank;
  final bool isGroup;

  OfficialFoodAlias toAlias() {
    return OfficialFoodAlias(
      alias: alias,
      reading: reading,
      normalized: normalized,
      priority: priority,
      isCandidate: isCandidate,
      candidateRank: candidateRank,
    );
  }
}

extension on ManualSpokenAlias {
  _AliasRow toAliasRow() {
    final alias = toAlias();
    return _AliasRow(
      foodCode: foodCode,
      alias: this.alias,
      reading: reading,
      normalized: alias.normalized,
      priority: alias.priority,
      isCandidate: isCandidate,
      candidateRank: candidateRank,
    );
  }
}

class _Score {
  int total = 0;
  int top1 = 0;
  int top3 = 0;
  final misses = <String>[];
}

_Score _scoreFoods(
  OfficialFoodRanker ranker,
  List<OfficialFoodCatalogItem> catalog,
  List<_Query> queries, {
  required bool fuzzy,
}) {
  final score = _Score();
  final seen = <String>{};
  for (final query in queries) {
    if (!seen.add(query.text)) {
      continue;
    }
    score.total += 1;
    final hits = ranker.search(
      query: query.text,
      catalog: catalog,
      limit: 5,
      fuzzyFallback: fuzzy,
    );
    final codes = hits.map((hit) => hit.foodCode).toList();
    final topOk = codes.isNotEmpty && codes.first == query.top1;
    final top3Ok = codes.take(3).contains(query.top1);
    if (topOk) {
      score.top1 += 1;
    }
    if (top3Ok) {
      score.top3 += 1;
    } else {
      score.misses.add(
        '${query.bucket} ${query.text} -> ${codes.take(3).join(",")} want ${query.top1}',
      );
    }
  }
  return score;
}

List<String> _lostTop1(
  OfficialFoodRanker ranker,
  List<OfficialFoodCatalogItem> before,
  List<OfficialFoodCatalogItem> after,
  List<_Query> queries,
) {
  final lost = <String>[];
  final seen = <String>{};
  for (final query in queries) {
    if (!seen.add(query.text)) {
      continue;
    }
    final oldHits = ranker.search(
      query: query.text,
      catalog: before,
      limit: 1,
      fuzzyFallback: false,
    );
    if (oldHits.isEmpty || oldHits.first.foodCode != query.top1) {
      continue;
    }
    final next = ranker.search(
      query: query.text,
      catalog: after,
      limit: 1,
      fuzzyFallback: true,
    );
    if (next.isEmpty || next.first.foodCode != query.top1) {
      final confirmed =
          next.isNotEmpty &&
          !next.first.isCandidate &&
          next.first.matchedAlias != null &&
          next.first.matchedAlias!.isNotEmpty;
      if (confirmed) {
        continue;
      }
      lost.add(
        '${query.text} was ${query.top1} now ${next.isEmpty ? "-" : next.first.foodCode}',
      );
    }
  }
  return lost;
}

class _SpeechScore {
  _SpeechScore(this.total);

  final int total;
  int beforeTop1 = 0;
  int beforeTop3 = 0;
  int afterTop1 = 0;
  int afterTop3 = 0;
  final misses = <String>[];
}

_SpeechScore _scoreUtterances(
  OfficialFoodRanker ranker,
  List<OfficialFoodCatalogItem> before,
  List<OfficialFoodCatalogItem> after,
) {
  const cases = <(String, String, String?)>[
    ('ささみ100g', '11227', '100'),
    ('ささみを100グラム', '11227', '100'),
    ('えーと、ささみ100g', '11227', '100'),
    ('あの、鶏ささみ100g', '11227', '100'),
    ('ご飯大盛り', '01088', null),
    ('ごはん大盛り', '01088', null),
    ('白米を200g', '01088', '200'),
    ('ライス大盛り', '01088', null),
    ('たまご', '12004', null),
    ('卵', '12004', null),
    ('納豆1パック', '04046', null),
    ('バナナ', '07107', null),
    ('牛乳', '13003', null),
    ('食パン', '01026', null),
    ('鶏むね100g', '11220', '100'),
    ('サラダチキン100g', '11220', '100'),
    ('味噌汁', '17049', null),
    ('ラーメン', '01048', null),
    ('カレー', '18001', null),
    ('えーと、あの、ご飯', '01088', null),
  ];
  final score = _SpeechScore(cases.length);
  for (final item in cases) {
    final query = _foodQuery(item.$1);
    final beforeHits = _asRemote(
      ranker.search(query: query, catalog: before, limit: 5, fuzzyFallback: false),
    );
    final afterHits = _asRemote(
      ranker.search(query: query, catalog: after, limit: 5, fuzzyFallback: true),
    );
    final beforePlan = _planFood(item.$1, beforeHits);
    final afterPlan = _planFood(item.$1, afterHits);
    if (_speechHit(beforePlan, item.$2, top3: false)) {
      score.beforeTop1 += 1;
    }
    if (_speechHit(beforePlan, item.$2, top3: true)) {
      score.beforeTop3 += 1;
    }
    final top1 = _speechHit(afterPlan, item.$2, top3: false);
    final top3 = _speechHit(afterPlan, item.$2, top3: true);
    if (top1) {
      score.afterTop1 += 1;
    }
    if (top3) {
      score.afterTop3 += 1;
    }
    final amountOk = afterPlan.asksChoice
        ? true
        : (item.$3 == null
              ? afterPlan.asksAmount && afterPlan.spoken.contains('何')
              : afterPlan.quantity?.amount == double.parse(item.$3!));
    if (!top1 || !amountOk) {
      score.misses.add(
        '${item.$1} q=$query food=${afterPlan.food?.officialFoodCode} '
        'choices=${afterPlan.choices.map((choice) => choice.id).join(",")} '
        'spoken=${afterPlan.spoken} amount=${afterPlan.quantity?.amount}',
      );
    }
  }
  return score;
}

bool _speechHit(SiriVoicePlan plan, String code, {required bool top3}) {
  final ids = <String>[
    if (plan.food?.officialFoodCode != null) plan.food!.officialFoodCode!,
    ...plan.choices.map((choice) => choice.id),
  ];
  if (ids.isEmpty) {
    return false;
  }
  if (!top3) {
    return ids.first == code;
  }
  return ids.take(3).contains(code);
}

SiriVoicePlan _planFood(String utterance, List<SiriFoodRecord> remote) {
  return planSiriFood(
    context: SiriVoiceContext(
      paid: true,
      ownerUserId: 'user-1',
      foods: const [],
      remoteOfficial: remote,
    ),
    name: utterance,
    quantity: '',
  );
}

List<SiriFoodRecord> _asRemote(List<OfficialFoodMatch> hits) {
  return [
    for (final hit in hits)
      SiriFoodRecord.official(
        foodCode: hit.foodCode,
        name: hit.name,
        speakName: (hit.displayName == null || hit.displayName!.isEmpty)
            ? hit.name
            : hit.displayName!,
        matchTexts: [
          hit.displayName ?? '',
          hit.name,
          hit.matchedAlias ?? '',
        ],
        baseAmount: 100,
        unit: hit.unitType == 'ml' ? FoodUnitType.ml : FoodUnitType.g,
        kcalPerBase: hit.kcal ?? 100,
        isCandidate: hit.isCandidate,
        candidateRank: hit.candidateRank ?? 100,
        priority: hit.priority,
        searchRank: hit.matchRank,
        searchAliasMatched: hit.matchedAlias != null && hit.matchedAlias!.isNotEmpty,
      ),
  ];
}

String _foodQuery(String utterance) {
  final options = siriSpeechInterpretations(utterance);
  final folded = options.isEmpty
      ? utterance
      : foldSiriSpokenQuantities(options.first);
  final compact = folded.replaceAll(' ', '').replaceAll('　', '');
  final tail = RegExp(
    r'(\d+(?:\.\d+)?)(ミリリットル|キロメートル|グラム|分間|食分|ml|mL|km|キロ|個|こ|食|分|回|g|G|ｇ)$',
  ).firstMatch(compact);
  if (tail != null && tail.start > 0) {
    return compact.substring(0, tail.start);
  }
  final vague = splitSiriVagueTail(compact);
  if (vague != null && vague.name.trim().isNotEmpty) {
    return vague.name;
  }
  return compact;
}

class _ExerciseScore {
  _ExerciseScore(this.total);

  final int total;
  int beforeTop1 = 0;
  int afterTop1 = 0;
  final misses = <String>[];
}

_ExerciseScore _scoreExercises() {
  const cases = <(String, String)>[
    ('散歩', 'walk_brisk'),
    ('ウォーキング', 'walk_brisk'),
    ('ジョギング', 'jogging'),
    ('ランニング', 'running'),
    ('筋トレ', 'weight_training'),
    ('ヨガ', 'yoga'),
    ('水泳', 'swim_lap'),
    ('自転車', 'cycle_road'),
    ('なわとび', 'jump_rope'),
    ('ダンス', 'dance'),
    ('ストレッチ', 'stretch'),
    ('腹筋', 'sit_up'),
    ('スクワット', 'squat'),
    ('バスケ', 'basketball'),
    ('サッカー', 'soccer'),
    ('テニス', 'tennis'),
    ('卓球', 'table_tennis'),
    ('ゴルフ', 'golf'),
    ('ヨガ30分', 'yoga'),
    ('散歩した', 'walk_brisk'),
    ('ランニング5km', 'running'),
    ('筋トレして', 'weight_training'),
    ('ジョギング30分', 'jogging'),
    ('自転車10km', 'cycle_road'),
    ('水泳20分', 'swim_lap'),
  ];
  final score = _ExerciseScore(cases.length);
  for (final item in cases) {
    final name = _exerciseQuery(item.$1);
    final previous = _exerciseIdWithoutStem(name);
    if (previous == item.$2) {
      score.beforeTop1 += 1;
    } else {
      score.misses.add('before ${item.$1} q=$name -> $previous');
    }
    final plan = planSiriExercise(
      context: const SiriVoiceContext(
        paid: true,
        ownerUserId: 'user-1',
        weightKg: 60,
        foods: [],
      ),
      name: item.$1,
      quantity: '',
    );
    if (plan.activityId == item.$2) {
      score.afterTop1 += 1;
    } else {
      score.misses.add('after ${item.$1} -> ${plan.activityId} ${plan.spoken}');
    }
  }
  return score;
}

String _exerciseQuery(String utterance) {
  final compact = utterance.replaceAll(' ', '').replaceAll('　', '');
  final tail = RegExp(
    r'(\d+(?:\.\d+)?)(キロメートル|分間|キロ|km|分)$',
  ).firstMatch(compact);
  if (tail != null && tail.start > 0) {
    return compact.substring(0, tail.start);
  }
  final vague = splitSiriVagueTail(compact);
  if (vague != null && vague.name.trim().isNotEmpty) {
    return vague.name;
  }
  return compact;
}

String? _exerciseIdWithoutStem(String name) {
  final spoken = spokenExerciseActivityId(name);
  if (spoken != null) {
    return spoken;
  }
  String? bestId;
  var bestRank = 9;
  for (final activity in MetActivityCatalog.activities) {
    if (!activity.searchable) {
      continue;
    }
    for (final variant in siriQueryVariants(name)) {
      for (final alias in activity.aliases) {
        final rank = siriTextRank(
          FoodSearchNormalizer.normalize(alias),
          variant,
        );
        if (rank < bestRank) {
          bestRank = rank;
          bestId = activity.id;
        }
      }
    }
  }
  if (bestRank >= 9) {
    return null;
  }
  return bestId;
}

List<_Query> _handQueries() {
  const rows = <(String, String)>[
    ('さざみ', '11227'),
    ('ささみい', '11227'),
    ('たまこ', '12004'),
    ('ばななな', '07107'),
    ('ぎゅうにゅ', '13003'),
    ('なっと', '04046'),
    ('ごはんん', '01088'),
    ('サラチキ', '11220'),
    ('むねにく', '11220'),
    ('とりむねにく', '11220'),
  ];
  return [
    for (final row in rows) _Query(row.$1, row.$2, {row.$2}, 'ゆらぎ'),
  ];
}

String _best(List<_Fact> facts) {
  final ordered = [...facts]..sort((a, b) {
    final candidate = (a.isCandidate ? 1 : 0).compareTo(b.isCandidate ? 1 : 0);
    if (candidate != 0) {
      return candidate;
    }
    final rank = (a.candidateRank ?? a.priority).compareTo(
      b.candidateRank ?? b.priority,
    );
    if (rank != 0) {
      return rank;
    }
    final priority = a.priority.compareTo(b.priority);
    if (priority != 0) {
      return priority;
    }
    return a.code.compareTo(b.code);
  });
  return ordered.first.code;
}

List<OfficialFoodCatalogItem> _catalog(
  Map<String, ({String display, String reading})> foods,
  List<_AliasRow> aliases,
) {
  final byCode = <String, List<OfficialFoodAlias>>{};
  final seen = <String>{};
  for (final row in aliases) {
    if (!foods.containsKey(row.foodCode)) {
      continue;
    }
    final key = '${row.foodCode}|${row.normalized}|${row.isCandidate}|${row.candidateRank}';
    if (!seen.add(key)) {
      continue;
    }
    byCode.putIfAbsent(row.foodCode, () => []).add(row.toAlias());
  }
  final items = <OfficialFoodCatalogItem>[];
  for (final entry in foods.entries) {
    items.add(
      OfficialFoodCatalogItem(
        food: OfficialFoodMatch(
          foodCode: entry.key,
          name: entry.value.display,
          displayName: entry.value.display,
          reading: entry.value.reading,
          kcal: 100,
        ),
        aliases: byCode[entry.key] ?? const [],
      ),
    );
  }
  return items;
}

List<_AliasRow> _generated(
  Map<String, ({String display, String reading})> foods,
) {
  final rows = <_AliasRow>[];
  for (final entry in foods.entries) {
    final spoken = officialFoodSpokenName(entry.value.display);
    for (final alias in officialFoodSpokenAliases(entry.value.display)) {
      final full = alias == spoken;
      rows.add(
        _AliasRow(
          foodCode: entry.key,
          alias: alias,
          reading: alias,
          normalized: FoodSearchNormalizer.normalize(alias),
          priority: full ? 180 : 160,
          isCandidate: true,
          candidateRank: full ? 900 : 800,
        ),
      );
    }
  }
  return rows;
}

List<_AliasRow> _siriAliases() {
  return const [
    _AliasRow(
      foodCode: '11220',
      alias: 'とりむね',
      reading: 'とりむね',
      normalized: 'とりむね',
      priority: 10,
      isCandidate: false,
    ),
    _AliasRow(
      foodCode: '11220',
      alias: 'むね肉',
      reading: 'むねにく',
      normalized: 'むね肉',
      priority: 10,
      isCandidate: false,
    ),
    _AliasRow(
      foodCode: '11220',
      alias: '胸肉',
      reading: 'むねにく',
      normalized: '胸肉',
      priority: 10,
      isCandidate: false,
    ),
  ];
}

Map<String, ({String display, String reading})> _parseDisplays(String sql) {
  final pattern = RegExp(
    r"^\('(\d{5})', '((?:[^']|'')*)', '((?:[^']|'')*)'\),?\s*$",
  );
  final foods = <String, ({String display, String reading})>{};
  for (final line in sql.split('\n')) {
    final match = pattern.firstMatch(line.trim());
    if (match == null) {
      continue;
    }
    foods[match.group(1)!] = (
      display: match.group(2)!.replaceAll("''", "'"),
      reading: match.group(3)!.replaceAll("''", "'"),
    );
  }
  return foods;
}

List<_AliasRow> _parseLabelAliases(String sql) {
  final pattern = RegExp(
    r"^\('(\d{5})', '((?:[^']|'')*)', '((?:[^']|'')*)', '((?:[^']|'')*)', (true|false), (null|\d+), '((?:[^']|'')*)', (true|false)\),?\s*$",
  );
  final rows = <_AliasRow>[];
  for (final line in sql.split('\n')) {
    final match = pattern.firstMatch(line.trim());
    if (match == null) {
      continue;
    }
    rows.add(
      _AliasRow(
        foodCode: match.group(1)!,
        alias: match.group(2)!.replaceAll("''", "'"),
        reading: match.group(3)!.replaceAll("''", "'"),
        normalized: match.group(4)!.replaceAll("''", "'"),
        isCandidate: match.group(5) == 'true',
        candidateRank: match.group(6) == 'null' ? null : int.parse(match.group(6)!),
        priority: 100,
        isGroup: match.group(8) == 'true',
      ),
    );
  }
  return rows;
}

List<_AliasRow> _parseCsv(String csv) {
  final lines = csv.split('\n');
  final rows = <_AliasRow>[];
  for (final raw in lines.skip(1)) {
    if (raw.trim().isEmpty) {
      continue;
    }
    final parts = raw.split(',');
    if (parts.length < 6) {
      continue;
    }
    final alias = parts[0];
    final reading = parts[1];
    final code = parts[3];
    final priority = int.tryParse(parts[5]) ?? 100;
    final tail = parts.length >= 9 ? parts.sublist(parts.length - 2) : const <String>[];
    final isCandidate = tail.isNotEmpty && tail[0] == 'true';
    final rank = tail.length == 2 && tail[1].isNotEmpty ? int.tryParse(tail[1]) : null;
    rows.add(
      _AliasRow(
        foodCode: code,
        alias: alias,
        reading: reading,
        normalized: FoodSearchNormalizer.normalize(alias),
        priority: priority,
        isCandidate: isCandidate,
        candidateRank: rank,
      ),
    );
  }
  return rows;
}

String _pct(int hit, int total) {
  if (total == 0) {
    return '0.0%';
  }
  return '${(100 * hit / total).toStringAsFixed(1)}%';
}

String _readRepo(String relative) {
  final direct = File(relative);
  if (direct.existsSync()) {
    return direct.readAsStringSync();
  }
  return File('/workspace/$relative').readAsStringSync();
}
