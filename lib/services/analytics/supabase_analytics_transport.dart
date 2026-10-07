import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import 'analytics_sender.dart';

/// `app_events` へまとめて upsert する。結果の行は受け取らない。
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
      await client.from('app_events').upsert(
        rows,
        onConflict: 'event_id,occurred_at',
        ignoreDuplicates: true,
      );
      return const AnalyticsSendResult.success();
    } on AuthException catch (error, stackTrace) {
      debugPrint('[AYG] analytics unauthorized: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const AnalyticsSendResult(statusCode: 401);
    } on PostgrestException catch (error, stackTrace) {
      debugPrint('[AYG] analytics rejected: ${error.code}');
      debugPrintStack(stackTrace: stackTrace);
      return AnalyticsSendResult(statusCode: _statusForPostgrest(error));
    } catch (error, stackTrace) {
      debugPrint('[AYG] analytics transport failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const AnalyticsSendResult();
    }
  }
}

int _statusForPostgrest(PostgrestException error) {
  final code = error.code ?? '';
  if (code == 'PGRST301' || code == '401') {
    return 401;
  }
  if (code == 'PGRST204' || code.startsWith('22') || code.startsWith('23')) {
    return 400;
  }
  final http = int.tryParse(code);
  if (http != null) {
    return http;
  }
  return 500;
}

Future<void> uploadAnalyticsConsent(Map<String, Object?> row) async {
  if (!SupabaseConfig.isConfigured) {
    return;
  }
  await Supabase.instance.client.from('analytics_consents').insert(row);
}
