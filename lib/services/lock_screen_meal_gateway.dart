import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lock_screen_meal.dart';

/// ロック画面の割り当てと、有料フラグの読み書き。
///
/// [setPaid] は課金処理のための入口だけ。設定画面からは呼ばない。
abstract class LockScreenMealGateway {
  Future<LockScreenMealConfig> loadConfig();

  Future<void> saveConfig(LockScreenMealConfig config);

  Future<bool> isPaid();

  Future<void> setPaid(bool isPaid);

  Future<void> publishSnapshot(LockScreenMealSnapshot snapshot);

  Future<List<PendingLockScreenMeal>> readPending();

  Future<void> acknowledge(List<String> registrationIds);
}

class LockScreenMealGatewayImpl implements LockScreenMealGateway {
  LockScreenMealGatewayImpl({
    SharedPreferences? preferences,
    MethodChannel? channel,
  }) : _preferences = preferences,
       _channel =
           channel ?? const MethodChannel(lockScreenMealMethodChannel);

  static const String configKey = 'lock_screen_meal_config_v1';

  SharedPreferences? _preferences;
  final MethodChannel _channel;

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  @override
  Future<LockScreenMealConfig> loadConfig() async {
    final preferences = await _prefs();
    return LockScreenMealCodec.decodeConfig(preferences.getString(configKey));
  }

  @override
  Future<void> saveConfig(LockScreenMealConfig config) async {
    final preferences = await _prefs();
    await preferences.setString(
      configKey,
      LockScreenMealCodec.encodeConfig(config),
    );
  }

  @override
  Future<bool> isPaid() async {
    final preferences = await _prefs();
    return LockScreenMealPaidFlag.readValue(
      preferences.getBool(LockScreenMealPaidFlag.storageKey),
    );
  }

  @override
  Future<void> setPaid(bool isPaid) async {
    final preferences = await _prefs();
    await preferences.setBool(LockScreenMealPaidFlag.storageKey, isPaid);
    await _invoke('setPaid', {'paid': isPaid});
  }

  @override
  Future<void> publishSnapshot(LockScreenMealSnapshot snapshot) async {
    final paid = await isPaid();
    await _invoke('writeSnapshot', {
      'snapshot': LockScreenMealCodec.encodeSnapshot(snapshot),
      'paid': paid,
    });
  }

  @override
  Future<List<PendingLockScreenMeal>> readPending() async {
    final raw = await _invoke('readPending');
    if (raw is! String) {
      return const [];
    }
    return LockScreenMealCodec.decodePending(raw);
  }

  @override
  Future<void> acknowledge(List<String> registrationIds) async {
    if (registrationIds.isEmpty) {
      return;
    }
    await _invoke('acknowledge', {'ids': registrationIds});
  }

  Future<Object?> _invoke(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<Object?>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
