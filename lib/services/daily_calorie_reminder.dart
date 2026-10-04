import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'daily_calorie_reminder_copy.dart';

const dailyCalorieReminderChannel = 'com.narutoaii.ayg/daily_calorie_reminder';

/// ログアウト時と、ホーム表示時に呼ぶ。テストは何もしない実装を渡す。
abstract class DailyReminderSession {
  Future<void> sync({required bool requestIfNeeded});

  Future<void> unregisterDevice();
}

class NoOpDailyReminderSession implements DailyReminderSession {
  const NoOpDailyReminderSession();

  @override
  Future<void> sync({required bool requestIfNeeded}) async {}

  @override
  Future<void> unregisterDevice() async {}
}

class DailyReminderGateway {
  DailyReminderGateway({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(dailyCalorieReminderChannel);

  final MethodChannel _channel;

  Future<String> authorizationStatus() async {
    final value = await _channel.invokeMethod<String>('authorizationStatus');
    return value ?? 'unknown';
  }

  Future<String> requestAuthorization() async {
    final value = await _channel.invokeMethod<String>('requestAuthorization');
    return value ?? 'denied';
  }

  Future<String?> deviceToken() async {
    final value = await _channel.invokeMethod<String>('deviceToken');
    final token = value?.trim().toLowerCase();
    if (token == null || token.isEmpty) {
      return null;
    }
    return token;
  }

  Future<String?> storedDeviceToken() async {
    final value = await _channel.invokeMethod<String>('storedDeviceToken');
    final token = value?.trim().toLowerCase();
    if (token == null || token.isEmpty) {
      return null;
    }
    return token;
  }

  Future<void> clearStoredDeviceToken() async {
    await _channel.invokeMethod<void>('clearStoredDeviceToken');
  }
}

class IosDailyReminderSession implements DailyReminderSession {
  IosDailyReminderSession({
    DailyReminderGateway? gateway,
    SupabaseClient? client,
  }) : _gateway = gateway ?? DailyReminderGateway(),
       _client = client;

  final DailyReminderGateway _gateway;
  final SupabaseClient? _client;

  @override
  Future<void> sync({required bool requestIfNeeded}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      var status = await _gateway.authorizationStatus();
      if (dailyReminderShouldRequest(
        status: status,
        requestIfNeeded: requestIfNeeded,
      )) {
        status = await _gateway.requestAuthorization();
      }
      if (!dailyReminderShouldUploadToken(status)) {
        return;
      }
      final supabase = _supabase;
      final userId = supabase?.auth.currentUser?.id;
      if (supabase == null || userId == null) {
        return;
      }
      final token = await _gateway.deviceToken();
      if (token == null) {
        return;
      }
      await supabase.from('user_push_tokens').upsert({
        'user_id': userId,
        'device_token': token,
        'platform': 'ios',
        'apns_environment': kReleaseMode ? 'production' : 'sandbox',
      }, onConflict: 'user_id,device_token');
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[AYG] daily reminder sync skipped: $error');
      }
    }
  }

  @override
  Future<void> unregisterDevice() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      final token = await _gateway.storedDeviceToken();
      final supabase = _supabase;
      final userId = supabase?.auth.currentUser?.id;
      if (supabase != null && userId != null && token != null) {
        await supabase
            .from('user_push_tokens')
            .delete()
            .eq('user_id', userId)
            .eq('device_token', token);
      }
      await _gateway.clearStoredDeviceToken();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[AYG] daily reminder unregister skipped: $error');
      }
    }
  }

  SupabaseClient? get _supabase {
    if (!SupabaseConfig.isConfigured) {
      return null;
    }
    return _client ?? Supabase.instance.client;
  }
}
