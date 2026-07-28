import 'package:shared_preferences/shared_preferences.dart';

/// 端末ローカルの認証セッション情報（Supabase非同期）。
class LocalSessionStore {
  LocalSessionStore({SharedPreferences? preferences})
    : _preferencesFuture = preferences != null
          ? Future.value(_PreferencesHandle.available(preferences))
          : _PreferencesHandle.load();

  final Future<_PreferencesHandle> _preferencesFuture;
  static const _lastUserIdKey = 'last_authenticated_user_id';

  Future<String?> loadLastUserId() async {
    final handle = await _preferencesFuture;
    return handle.getString(_lastUserIdKey);
  }

  Future<void> saveLastUserId(String userId) async {
    final handle = await _preferencesFuture;
    await handle.setString(_lastUserIdKey, userId);
  }

  Future<void> clearLastUserId() async {
    final handle = await _preferencesFuture;
    await handle.remove(_lastUserIdKey);
  }
}

class _PreferencesHandle {
  _PreferencesHandle._({
    SharedPreferences? preferences,
    Map<String, String>? memory,
  }) : _preferences = preferences,
       _memory = memory ?? <String, String>{};

  factory _PreferencesHandle.available(SharedPreferences preferences) {
    return _PreferencesHandle._(preferences: preferences);
  }

  factory _PreferencesHandle.memoryOnly() {
    return _PreferencesHandle._();
  }

  static Future<_PreferencesHandle> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return _PreferencesHandle.available(preferences);
    } catch (_) {
      return _PreferencesHandle.memoryOnly();
    }
  }

  final SharedPreferences? _preferences;
  final Map<String, String> _memory;

  String? getString(String key) {
    return _preferences?.getString(key) ?? _memory[key];
  }

  Future<void> setString(String key, String value) async {
    _memory[key] = value;
    try {
      await _preferences?.setString(key, value);
    } catch (_) {}
  }

  Future<void> remove(String key) async {
    _memory.remove(key);
    try {
      await _preferences?.remove(key);
    } catch (_) {}
  }
}
