import 'package:shared_preferences/shared_preferences.dart';

/// 端末ローカルの認証セッション情報（Supabase非同期）。
class LocalSessionStore {
  LocalSessionStore({SharedPreferences? preferences})
    : _preferencesFuture = preferences != null
          ? Future.value(preferences)
          : SharedPreferences.getInstance();

  final Future<SharedPreferences> _preferencesFuture;
  static const _lastUserIdKey = 'last_authenticated_user_id';

  Future<String?> loadLastUserId() async {
    final preferences = await _preferencesFuture;
    return preferences.getString(_lastUserIdKey);
  }

  Future<void> saveLastUserId(String userId) async {
    final preferences = await _preferencesFuture;
    await preferences.setString(_lastUserIdKey, userId);
  }

  Future<void> clearLastUserId() async {
    final preferences = await _preferencesFuture;
    await preferences.remove(_lastUserIdKey);
  }
}
