import 'package:ayg/constants/official_food_limits.dart';
import 'package:ayg/models/official_food.dart';
import 'package:ayg/services/official_food_ranker.dart';
import 'package:ayg/utils/food_search_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

OfficialFoodCatalogItem _food(
  String code,
  String name,
  double kcal,
  List<OfficialFoodAlias> aliases,
) {
  return OfficialFoodCatalogItem(
    food: OfficialFoodMatch(
      foodCode: code,
      name: name,
      displayName: name,
      kcal: kcal,
      proteinG: 1,
      fatG: 1,
      carbG: 1,
    ),
    aliases: aliases,
  );
}

OfficialFoodAlias _alias(
  String alias,
  String reading, {
  bool isCandidate = false,
  int? candidateRank,
}) {
  return OfficialFoodAlias(
    alias: alias,
    reading: reading,
    normalized: FoodSearchNormalizer.normalize(alias),
    isCandidate: isCandidate,
    candidateRank: candidateRank,
  );
}

void main() {
  final catalog = [
    _food('01088', 'こめ　［水稲めし］　精白米　うるち米', 156, [
      _alias('ごはん', 'ごはん'),
      _alias('ご飯', 'ごはん'),
      _alias('白米', 'はくまい'),
      _alias('ライス', 'らいす'),
      _alias('牛丼', 'ぎゅうどん', isCandidate: true, candidateRank: 2),
    ]),
    _food('01085', 'こめ　［水稲めし］　玄米', 152, [
      _alias('玄米ご飯', 'げんまいごはん'),
      _alias('ご飯', 'ごはん', isCandidate: true, candidateRank: 1),
    ]),
    _food('01154', 'こめ　［水稲めし］　精白米　もち米', 156, [
      _alias('もち米', 'もちごめ'),
    ]),
    _food('01048', 'こむぎ　［中華めん類］　中華めん　ゆで', 149, [
      _alias('ラーメン', 'らーめん'),
    ]),
    _food('12004', '鶏卵　全卵　生', 142, [
      _alias('たまご', 'たまご'),
      _alias('玉子', 'たまご'),
    ]),
    _food('11220', '＜鳥肉類＞　にわとり　［若どり・主品目］　むね　皮なし　生', 105, [
      _alias('鶏むね', 'とりむね'),
    ]),
    _food('04032', 'だいず　［豆腐・油揚げ類］　木綿豆腐', 73, [
      _alias('とうふ', 'とうふ'),
    ]),
    _food('13003', '＜牛乳及び乳製品＞　（液状乳類）　普通牛乳', 61, [
      _alias('牛乳', 'ぎゅうにゅう'),
    ]),
    _food('18031', '和風料理　煮物類　牛飯の具', 147, [
      _alias('牛丼', 'ぎゅうどん', isCandidate: true, candidateRank: 1),
    ]),
  ];
  const ranker = OfficialFoodRanker();

  test('rice queries return 01088 first', () {
    for (final query in ['ご飯', 'ごはん', 'ゴハン', 'ｺﾞﾊﾝ', '白米', 'ライス']) {
      final hits = ranker.search(query: query, catalog: catalog);
      expect(hits, isNotEmpty, reason: query);
      expect(hits.first.foodCode, '01088', reason: query);
    }
  });

  test('alias matches rank with the official name', () {
    expect(
      ranker.search(query: 'たまご', catalog: catalog).first.foodCode,
      '12004',
    );
    expect(
      ranker.search(query: '玉子', catalog: catalog).first.foodCode,
      '12004',
    );
    expect(
      ranker.search(query: 'ラーメン', catalog: catalog).first.foodCode,
      '01048',
    );
    expect(
      ranker.search(query: 'らーめん', catalog: catalog).first.foodCode,
      '01048',
    );
    expect(
      ranker.search(query: '鶏むね', catalog: catalog).first.foodCode,
      '11220',
    );
    expect(
      ranker.search(query: 'とうふ', catalog: catalog).first.foodCode,
      '04032',
    );
    expect(
      ranker.search(query: 'ぎゅうにゅう', catalog: catalog).first.foodCode,
      '13003',
    );
  });

  test('an empty query returns nothing', () {
    expect(ranker.search(query: '   ', catalog: catalog), isEmpty);
  });

  test('牛丼 returns every candidate and exact aliases stay first', () {
    final gyudon = ranker.search(query: '牛丼', catalog: catalog);
    expect(gyudon.map((hit) => hit.foodCode), ['18031', '01088']);
    expect(gyudon.every((hit) => hit.isCandidate), isTrue);
    expect(gyudon[0].name, contains('牛飯の具'));
    expect(gyudon[1].name, contains('精白米'));
    expect(gyudon[1].name, contains('水稲めし'));

    final rice = ranker.search(query: 'ご飯', catalog: catalog);
    expect(rice.first.foodCode, '01088');
    expect(rice.first.isCandidate, isFalse);
    expect(rice[1].foodCode, '01085');
    expect(rice[1].isCandidate, isTrue);
  });

  test('a query longer than 64 characters uses only the prefix', () {
    final long = 'ご飯${'あ' * 100000}';
    expect(OfficialFoodLimits.cap(long).runes.length, 64);
    final capped = ranker.search(query: long, catalog: catalog);
    final prefix = ranker.search(
      query: OfficialFoodLimits.cap(long),
      catalog: catalog,
    );
    expect(
      capped.map((hit) => hit.foodCode),
      prefix.map((hit) => hit.foodCode),
    );
    expect(capped.where((hit) => hit.foodCode == '01088'), isEmpty);
    expect(
      ranker.search(query: 'ご飯', catalog: catalog).first.foodCode,
      '01088',
    );
  });
}
