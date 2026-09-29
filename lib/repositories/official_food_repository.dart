import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/official_foods_flag.dart';
import '../constants/official_food_limits.dart';
import '../models/official_food.dart';

/// 食品成分表の検索。失敗しても食事記録の画面は止めない。
abstract class OfficialFoodRepository {
  Future<List<OfficialFoodMatch>> search(String query, {int limit = 30});
}

class SupabaseOfficialFoodRepository implements OfficialFoodRepository {
  SupabaseOfficialFoodRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  @override
  Future<List<OfficialFoodMatch>> search(String query, {int limit = 30}) async {
    if (!OfficialFoodsFlag.enabled) {
      return const [];
    }
    final trimmed = OfficialFoodLimits.cap(query.trim());
    if (trimmed.isEmpty) {
      return const [];
    }
    try {
      final client = _client ?? Supabase.instance.client;
      final rows = await client
          .rpc(
            'search_official_foods',
            params: {'p_query': trimmed, 'p_limit': limit},
          )
          .timeout(const Duration(seconds: 8));
      if (rows is! List) {
        return const [];
      }
      return [
        for (final row in rows)
          if (row is Map)
            OfficialFoodMatch.fromRpc(Map<String, dynamic>.from(row)),
      ];
    } catch (_) {
      return const [];
    }
  }
}
