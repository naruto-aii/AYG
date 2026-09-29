import '../models/official_food.dart';

/// ある食品を選んで食事に記録した回数と、最後に記録した時刻。
class OfficialFoodSelection {
  const OfficialFoodSelection({
    required this.foodCode,
    required this.count,
    required this.lastSelectedAt,
  });

  final String foodCode;
  final int count;
  final DateTime lastSelectedAt;
}

/// 検索語ではなく、その利用者が食品を記録した回数で候補を並べる。
class OfficialFoodHistoryRanker {
  const OfficialFoodHistoryRanker();

  /// 選択歴がある候補を回数の多い順、同数は最近記録した順。
  /// 選択歴のない候補は、検索が返した順のまま後ろに置く。
  List<OfficialFoodMatch> reorder(
    List<OfficialFoodMatch> matches,
    Iterable<OfficialFoodSelection> selections,
  ) {
    if (matches.isEmpty) {
      return matches;
    }
    final byCode = <String, OfficialFoodSelection>{};
    for (final selection in selections) {
      final code = selection.foodCode.trim();
      if (code.isEmpty || selection.count <= 0) {
        continue;
      }
      final current = byCode[code];
      if (current == null ||
          selection.count > current.count ||
          (selection.count == current.count &&
              selection.lastSelectedAt.isAfter(current.lastSelectedAt))) {
        byCode[code] = OfficialFoodSelection(
          foodCode: code,
          count: selection.count,
          lastSelectedAt: selection.lastSelectedAt,
        );
      }
    }
    if (byCode.isEmpty) {
      return matches;
    }

    final withHistory = <int>[];
    final withoutHistory = <int>[];
    for (var index = 0; index < matches.length; index++) {
      if (_selectionFor(matches[index], byCode) == null) {
        withoutHistory.add(index);
      } else {
        withHistory.add(index);
      }
    }
    withHistory.sort((a, b) {
      final left = _selectionFor(matches[a], byCode)!;
      final right = _selectionFor(matches[b], byCode)!;
      final byCount = right.count.compareTo(left.count);
      if (byCount != 0) {
        return byCount;
      }
      final byTime = right.lastSelectedAt.compareTo(left.lastSelectedAt);
      if (byTime != 0) {
        return byTime;
      }
      return a.compareTo(b);
    });

    return [
      for (final index in withHistory) matches[index],
      for (final index in withoutHistory) matches[index],
    ];
  }

  /// `food_entries` の行を食品番号ごとに集計する。
  List<OfficialFoodSelection> summarize(Iterable<Map<String, dynamic>> rows) {
    final counts = <String, int>{};
    final latest = <String, DateTime>{};
    for (final row in rows) {
      final code = row['official_food_code']?.toString().trim() ?? '';
      if (code.isEmpty) {
        continue;
      }
      counts[code] = (counts[code] ?? 0) + 1;
      final loggedAt = _loggedAt(row['logged_at']);
      if (loggedAt == null) {
        continue;
      }
      final current = latest[code];
      if (current == null || loggedAt.isAfter(current)) {
        latest[code] = loggedAt;
      }
    }
    return [
      for (final entry in counts.entries)
        OfficialFoodSelection(
          foodCode: entry.key,
          count: entry.value,
          lastSelectedAt: latest[entry.key] ?? DateTime.utc(1970),
        ),
    ];
  }

  OfficialFoodSelection? _selectionFor(
    OfficialFoodMatch match,
    Map<String, OfficialFoodSelection> byCode,
  ) {
    final code = match.foodCode.trim();
    if (code.isEmpty) {
      return null;
    }
    return byCode[code];
  }

  DateTime? _loggedAt(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}
