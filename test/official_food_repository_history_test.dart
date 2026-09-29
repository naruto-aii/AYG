import 'package:ayg/config/official_foods_flag.dart';
import 'package:ayg/repositories/official_food_history_reader.dart';
import 'package:ayg/repositories/official_food_repository.dart';
import 'package:ayg/services/official_food_history_ranker.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedHistory implements OfficialFoodHistoryReader {
  _FixedHistory(this.selections, {this.seenCodes});

  final List<OfficialFoodSelection> selections;
  final List<String>? seenCodes;

  @override
  Future<List<OfficialFoodSelection>> selectionsFor(
    Iterable<String> foodCodes,
  ) async {
    seenCodes?.addAll(foodCodes);
    return selections;
  }
}

class _FailingHistory implements OfficialFoodHistoryReader {
  @override
  Future<List<OfficialFoodSelection>> selectionsFor(
    Iterable<String> foodCodes,
  ) async {
    throw StateError('history unavailable');
  }
}

void main() {
  setUp(() {
    OfficialFoodsFlag.debugOverride = true;
  });

  tearDown(() {
    OfficialFoodsFlag.debugOverride = null;
  });

  Future<dynamic> searchRows(String query, int limit) async {
    return [
      {'food_code': 'B', 'name': 'B'},
      {'food_code': 'C', 'name': 'C'},
      {'food_code': 'D', 'name': 'D'},
    ];
  }

  test('search puts the previously recorded food first', () async {
    final seen = <String>[];
    final repository = SupabaseOfficialFoodRepository(
      searchCall: searchRows,
      history: _FixedHistory([
        OfficialFoodSelection(
          foodCode: 'D',
          count: 1,
          lastSelectedAt: DateTime.utc(2026, 9, 1),
        ),
      ], seenCodes: seen),
    );

    final matches = await repository.search('A');

    expect(matches.map((match) => match.foodCode), ['D', 'B', 'C']);
    expect(seen, ['B', 'C', 'D']);
  });

  test('a history failure keeps the search order', () async {
    final repository = SupabaseOfficialFoodRepository(
      searchCall: searchRows,
      history: _FailingHistory(),
    );

    final matches = await repository.search('A');

    expect(matches.map((match) => match.foodCode), ['B', 'C', 'D']);
  });

  test('pages stop on a short page and skip a repeated entry id', () async {
    final calls = <int>[];
    final rows = await collectOfficialFoodHistoryPages(
      pageSize: 2,
      maxPages: 5,
      fetchPage: (from, to) async {
        calls.add(from);
        if (from == 0) {
          return [
            {'entry_id': 'a', 'official_food_code': 'D'},
            {'entry_id': 'b', 'official_food_code': 'D'},
          ];
        }
        if (from == 2) {
          return [
            {'entry_id': 'b', 'official_food_code': 'D'},
            {'entry_id': 'c', 'official_food_code': 'B'},
          ];
        }
        return const [];
      },
    );

    expect(calls, [0, 2, 4]);
    expect(rows.map((row) => row['entry_id']), ['a', 'b', 'c']);
  });
}
