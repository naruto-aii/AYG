import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_food_lookup.dart';
import 'photo_meal_client.dart';

typedef AiFoodLookupInvoke =
    Future<Object?> Function(Map<String, Object?> body);

/// Edge Function `lookup-food-text`。API キーはアプリに置かない。
class AiFoodLookupClient {
  const AiFoodLookupClient({required this.invoke});

  final AiFoodLookupInvoke invoke;

  factory AiFoodLookupClient.supabase({SupabaseClient? client}) {
    return AiFoodLookupClient(
      invoke: (body) async {
        final supabase = client ?? Supabase.instance.client;
        try {
          final response = await supabase.functions.invoke(
            'lookup-food-text',
            body: body,
          );
          return response.data;
        } on FunctionException catch (error) {
          throw PhotoMealFailure(photoMealMessageFromBody(error.details));
        }
      },
    );
  }

  Future<AiFoodLookupResult> lookup(String query) async {
    final Object? data;
    try {
      data = await invoke({'query': clipAiFoodQuery(query)});
    } on PhotoMealFailure {
      rethrow;
    } catch (error) {
      debugPrint('[AYG] ai food lookup invoke failed: $error');
      throw const PhotoMealFailure(photoMealFallbackMessage);
    }
    if (data is Map && data['ok'] == false) {
      throw PhotoMealFailure(photoMealMessageFromBody(data));
    }
    if (data is! Map) {
      throw const PhotoMealFailure(photoMealFallbackMessage);
    }
    final candidates = parseAiFoodCandidates(data['candidates']);
    if (candidates == null) {
      throw const PhotoMealFailure('推定を確認できませんでした。別の名前で探すか、手入力で記録できます。');
    }
    final usageId = data['usage_id'];
    return AiFoodLookupResult(
      usageId: usageId is String && usageId.isNotEmpty ? usageId : null,
      candidates: candidates,
      cacheHit: data['cache_hit'] == true,
    );
  }
}

/// 保存のあと、保存したことと直したかを本人の行へ書く。失敗しても食事の保存は戻さない。
Future<void> recordAiFoodLookupOutcome({
  SupabaseClient? client,
  required String usageId,
  required bool edited,
}) async {
  try {
    final supabase = client ?? Supabase.instance.client;
    await supabase
        .from('meal_text_lookups')
        .update({'saved': true, 'user_edited': edited})
        .eq('id', usageId);
  } catch (error) {
    debugPrint('[AYG] ai food lookup outcome failed: $error');
  }
}
