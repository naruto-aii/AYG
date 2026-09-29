import 'package:ayg/models/official_food.dart';
import 'package:ayg/services/official_food_history_ranker.dart';
import 'package:flutter_test/flutter_test.dart';

OfficialFoodMatch _match(String code, [String? name]) {
  return OfficialFoodMatch(foodCode: code, name: name ?? code);
}

void main() {
  const ranker = OfficialFoodHistoryRanker();
  final original = [_match('B'), _match('C'), _match('D')];

  test('a single past selection moves that food to the front', () {
    final ranked = ranker.reorder(original, [
      OfficialFoodSelection(
        foodCode: 'D',
        count: 1,
        lastSelectedAt: DateTime.utc(2026, 9, 1),
      ),
    ]);

    expect(ranked.map((match) => match.foodCode), ['D', 'B', 'C']);
  });

  test('higher selection counts come first', () {
    final ranked = ranker.reorder(original, [
      OfficialFoodSelection(
        foodCode: 'D',
        count: 1,
        lastSelectedAt: DateTime.utc(2026, 9, 2),
      ),
      OfficialFoodSelection(
        foodCode: 'B',
        count: 3,
        lastSelectedAt: DateTime.utc(2026, 1, 1),
      ),
    ]);

    expect(ranked.map((match) => match.foodCode), ['B', 'D', 'C']);
  });

  test('equal counts use the most recent selection', () {
    final ranked = ranker.reorder(original, [
      OfficialFoodSelection(
        foodCode: 'B',
        count: 2,
        lastSelectedAt: DateTime.utc(2026, 8, 1),
      ),
      OfficialFoodSelection(
        foodCode: 'D',
        count: 2,
        lastSelectedAt: DateTime.utc(2026, 9, 1),
      ),
    ]);

    expect(ranked.map((match) => match.foodCode), ['D', 'B', 'C']);
  });

  test('equal count and time keep the search order', () {
    final sameTime = DateTime.utc(2026, 9, 1);
    final ranked = ranker.reorder(original, [
      OfficialFoodSelection(foodCode: 'D', count: 1, lastSelectedAt: sameTime),
      OfficialFoodSelection(foodCode: 'B', count: 1, lastSelectedAt: sameTime),
    ]);

    expect(ranked.map((match) => match.foodCode), ['B', 'D', 'C']);
  });

  test('history for a food that is not in the results is ignored', () {
    final ranked = ranker.reorder(original, [
      OfficialFoodSelection(
        foodCode: '18031',
        count: 9,
        lastSelectedAt: DateTime.utc(2026, 9, 1),
      ),
    ]);

    expect(ranked.map((match) => match.foodCode), ['B', 'C', 'D']);
  });

  test('empty food codes are not treated as a shared history', () {
    final matches = [_match(''), _match('D')];
    final ranked = ranker.reorder(matches, [
      OfficialFoodSelection(
        foodCode: '',
        count: 4,
        lastSelectedAt: DateTime.utc(2026, 9, 1),
      ),
    ]);

    expect(ranked.map((match) => match.foodCode), ['', 'D']);
  });

  test('summarize counts rows and keeps the latest logged_at', () {
    final selections = ranker.summarize([
      {'official_food_code': '01088', 'logged_at': '2026-09-01T00:00:00Z'},
      {'official_food_code': '01088', 'logged_at': '2026-09-03T00:00:00Z'},
      {'official_food_code': '01085', 'logged_at': '2026-09-02T00:00:00Z'},
      {'official_food_code': '  ', 'logged_at': '2026-09-04T00:00:00Z'},
      {'official_food_code': null, 'logged_at': '2026-09-04T00:00:00Z'},
    ]);

    expect(selections, hasLength(2));
    final rice = selections.singleWhere((row) => row.foodCode == '01088');
    expect(rice.count, 2);
    expect(rice.lastSelectedAt, DateTime.utc(2026, 9, 3));
    final brown = selections.singleWhere((row) => row.foodCode == '01085');
    expect(brown.count, 1);
  });

  test('recorded rows reorder the search list by that user history', () {
    final matches = [
      _match('01088', '精白米'),
      _match('01085', '玄米'),
      _match('18031', '牛飯の具'),
    ];
    final selections = ranker.summarize([
      {'official_food_code': '18031', 'logged_at': '2026-09-01T01:00:00Z'},
      {'official_food_code': '01088', 'logged_at': '2026-08-01T01:00:00Z'},
      {'official_food_code': '01088', 'logged_at': '2026-08-02T01:00:00Z'},
    ]);

    final ranked = ranker.reorder(matches, selections);

    expect(ranked.map((match) => match.foodCode), ['01088', '18031', '01085']);
  });
}
