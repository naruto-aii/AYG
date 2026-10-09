import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// AI が not_plus を返したとき、端末に有効な商品があれば一度だけ同期して再試行する。
class PlusGateRetry {
  static Future<bool> Function()? syncIfLocalPlus;

  static void bind(Future<bool> Function()? sync) {
    syncIfLocalPlus = sync;
  }

  static bool isNotPlus(Object? body) {
    if (body is Map && body['code'] == 'not_plus') {
      return true;
    }
    if (body is String && body.trim().isNotEmpty) {
      try {
        return isNotPlus(jsonDecode(body));
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  static Future<Object?> callOnce(Future<Object?> Function() call) async {
    try {
      return await call();
    } on FunctionException catch (error) {
      if (!isNotPlus(error.details)) {
        rethrow;
      }
      final synced = await syncIfLocalPlus?.call() ?? false;
      if (!synced) {
        rethrow;
      }
    }
    return await call();
  }
}
