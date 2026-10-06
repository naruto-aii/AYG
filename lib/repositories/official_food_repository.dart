import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/official_foods_flag.dart';
import '../constants/official_food_limits.dart';
import '../models/official_food.dart';
import '../services/official_food_history_ranker.dart';
import 'official_food_history_reader.dart';

/// 食品成分表の検索。失敗しても食事記録の画面は止めない。
abstract class OfficialFoodRepository {
  Future<List<OfficialFoodMatch>> search(String query, {int limit = 30});
}

/// [OfficialFoodRepository.search] の成否。空の一覧と失敗を分ける。
class OfficialFoodSearchResult {
  const OfficialFoodSearchResult({this.matches = const [], this.error});

  factory OfficialFoodSearchResult.failed(Object error) {
    return OfficialFoodSearchResult(error: error);
  }

  final List<OfficialFoodMatch> matches;
  final Object? error;

  bool get failed => error != null;
}

/// テストから検索 RPC の戻りだけを差し替える。
typedef OfficialFoodSearchCall =
    Future<dynamic> Function(String query, int limit);

class SupabaseOfficialFoodRepository implements OfficialFoodRepository {
  SupabaseOfficialFoodRepository({
    SupabaseClient? client,
    OfficialFoodHistoryReader? history,
    OfficialFoodSearchCall? searchCall,
  }) : _client = client,
       _history = history,
       _searchCall = searchCall;

  final SupabaseClient? _client;
  final OfficialFoodHistoryReader? _history;
  final OfficialFoodSearchCall? _searchCall;

  @override
  Future<List<OfficialFoodMatch>> search(String query, {int limit = 30}) async {
    final result = await searchReporting(query, limit: limit);
    return result.matches;
  }

  /// 通信失敗を空の一覧と区別する。食事の保存は止めない。
  Future<OfficialFoodSearchResult> searchReporting(
    String query, {
    int limit = 30,
  }) async {
    if (!OfficialFoodsFlag.enabled) {
      return const OfficialFoodSearchResult();
    }
    final trimmed = OfficialFoodLimits.cap(query.trim());
    if (trimmed.isEmpty) {
      return const OfficialFoodSearchResult();
    }
    try {
      final rows = await _fetchRows(trimmed, limit);
      if (rows is! List) {
        return const OfficialFoodSearchResult();
      }
      final matches = [
        for (final row in rows)
          if (row is Map)
            OfficialFoodMatch.fromRpc(Map<String, dynamic>.from(row)),
      ];
      return OfficialFoodSearchResult(matches: await _applyHistory(matches));
    } catch (error) {
      return OfficialFoodSearchResult.failed(error);
    }
  }

  Future<dynamic> _fetchRows(String query, int limit) {
    final searchCall = _searchCall;
    if (searchCall != null) {
      return searchCall(query, limit);
    }
    final client = _client ?? Supabase.instance.client;
    return client
        .rpc(
          'search_official_foods',
          params: {'p_query': query, 'p_limit': limit},
        )
        .timeout(const Duration(seconds: 8));
  }

  Future<List<OfficialFoodMatch>> _applyHistory(
    List<OfficialFoodMatch> matches,
  ) async {
    if (matches.isEmpty) {
      return matches;
    }
    final history = _history;
    if (history == null && _searchCall != null) {
      return matches;
    }
    try {
      final reader =
          history ??
          SupabaseOfficialFoodHistoryReader(
            _client ?? Supabase.instance.client,
          );
      final selections = await reader.selectionsFor(
        matches.map((match) => match.foodCode),
      );
      return const OfficialFoodHistoryRanker().reorder(matches, selections);
    } catch (_) {
      return matches;
    }
  }
}
