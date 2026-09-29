import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/official_food_history_ranker.dart';

/// ログイン中の利用者だけが記録した食品の回数を読む。
abstract class OfficialFoodHistoryReader {
  Future<List<OfficialFoodSelection>> selectionsFor(Iterable<String> foodCodes);
}

/// `food_entries` を本人の行だけで集計する。
///
/// `food_entries_select_own` は `auth.uid() = user_id`。クエリでもセッションの
/// user id に絞るので、他の利用者の記録は混ざらない。
class SupabaseOfficialFoodHistoryReader implements OfficialFoodHistoryReader {
  SupabaseOfficialFoodHistoryReader(
    this._client, {
    this.pageSize = 1000,
    this.maxPages = 20,
  });

  final SupabaseClient _client;
  final int pageSize;
  final int maxPages;

  @override
  Future<List<OfficialFoodSelection>> selectionsFor(
    Iterable<String> foodCodes,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return const [];
    }
    final codes = foodCodes
        .map((code) => code.trim())
        .where((code) => code.isNotEmpty)
        .toSet()
        .toList();
    if (codes.isEmpty) {
      return const [];
    }

    final rows = await collectOfficialFoodHistoryPages(
      pageSize: pageSize,
      maxPages: maxPages,
      fetchPage: (from, to) async {
        final batch = await _client
            .from('food_entries')
            .select('entry_id, official_food_code, logged_at')
            .eq('user_id', userId)
            .inFilter('official_food_code', codes)
            .order('entry_id')
            .range(from, to)
            .timeout(const Duration(seconds: 8));
        return [for (final row in batch) Map<String, dynamic>.from(row)];
      },
    );
    return const OfficialFoodHistoryRanker().summarize(rows);
  }
}

/// 1,000 件を超える記録も、同じ行を二度数えずに集計する。
Future<List<Map<String, dynamic>>> collectOfficialFoodHistoryPages({
  required int pageSize,
  required int maxPages,
  required Future<List<Map<String, dynamic>>> Function(int from, int to)
  fetchPage,
}) async {
  final rows = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (var page = 0; page < maxPages; page++) {
    final start = page * pageSize;
    final batch = await fetchPage(start, start + pageSize - 1);
    if (batch.isEmpty) {
      break;
    }
    var added = 0;
    for (final row in batch) {
      final id = row['entry_id']?.toString();
      if (id != null && id.isNotEmpty && !seen.add(id)) {
        continue;
      }
      rows.add(row);
      added++;
    }
    if (added == 0 || batch.length < pageSize) {
      break;
    }
  }
  return rows;
}
