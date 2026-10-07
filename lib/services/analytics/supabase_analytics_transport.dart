import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import 'analytics_sender.dart';
import 'app_event_retention.dart';

/// `insert_app_events` でまとめて追加する。同じ event_id と occurred_at は無視する。
class SupabaseAnalyticsTransport implements AnalyticsTransport {
  SupabaseAnalyticsTransport({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient? get _supabase {
    if (_client != null) {
      return _client;
    }
    if (!SupabaseConfig.isConfigured) {
      return null;
    }
    return Supabase.instance.client;
  }

  @override
  Future<AnalyticsSendResult> send(List<Map<String, dynamic>> rows) async {
    final client = _supabase;
    if (client == null) {
      return const AnalyticsSendResult();
    }
    try {
      final raw = await client.rpc(
        'insert_app_events',
        params: {'events': rows},
      );
      return AnalyticsSendResult.success(
        rejectedEventIds: rejectedEventIdsFromInsert(raw),
      );
    } on AuthException catch (error, stackTrace) {
      debugPrint('[AYG] analytics unauthorized: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const AnalyticsSendResult(statusCode: 401);
    } on PostgrestException catch (error, stackTrace) {
      debugPrint('[AYG] analytics rejected: ${error.code}');
      debugPrintStack(stackTrace: stackTrace);
      return AnalyticsSendResult(
        statusCode: analyticsStatusForPostgrest(error),
      );
    } catch (error, stackTrace) {
      debugPrint('[AYG] analytics transport failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const AnalyticsSendResult();
    }
  }
}

int analyticsStatusForPostgrest(PostgrestException error) {
  final code = error.code ?? '';
  if (code == 'PGRST301' || code == '401') {
    return 401;
  }
  if (code == 'PGRST202' ||
      code == 'PGRST205' ||
      code == '42P01' ||
      code == '42883' ||
      code == '404') {
    return 404;
  }
  if (code == 'PGRST204' || code.startsWith('22') || code.startsWith('23')) {
    return 400;
  }
  if (code.startsWith('PGRST')) {
    return 400;
  }
  final http = int.tryParse(code);
  if (http != null) {
    return http;
  }
  final message = error.message.toLowerCase();
  if (message.contains('invalid') ||
      message.contains('malformed') ||
      message.contains('check constraint') ||
      message.contains('violates')) {
    return 400;
  }
  return 500;
}

Future<void> uploadAnalyticsConsent(Map<String, Object?> row) async {
  if (!SupabaseConfig.isConfigured) {
    return;
  }
  await Supabase.instance.client.from('analytics_consents').insert(row);
}
