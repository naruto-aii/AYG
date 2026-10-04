import 'package:shared_preferences/shared_preferences.dart';

/// 今日のコーチを無料で開いた回数。端末の日付ごとに1回まで。
abstract class CoachUsageStore {
  Future<int> opensOn(DateTime day);
  Future<void> recordOpen(DateTime day);
}

class PreferencesCoachUsageStore implements CoachUsageStore {
  PreferencesCoachUsageStore({this._preferences});

  static const storageKey = 'coach_daily_opens_v1';

  final SharedPreferences? _preferences;

  @override
  Future<int> opensOn(DateTime day) async {
    final raw = (await _prefs()).getString(storageKey);
    if (raw == null) {
      return 0;
    }
    final parts = raw.split(':');
    if (parts.length != 2 || parts[0] != _dayKey(day)) {
      return 0;
    }
    return int.tryParse(parts[1]) ?? 0;
  }

  @override
  Future<void> recordOpen(DateTime day) async {
    final prefs = await _prefs();
    final next = await opensOn(day) + 1;
    await prefs.setString(storageKey, '${_dayKey(day)}:$next');
  }

  Future<SharedPreferences> _prefs() async {
    return _preferences ?? await SharedPreferences.getInstance();
  }

  static String _dayKey(DateTime day) {
    final month = day.month.toString().padLeft(2, '0');
    final date = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$date';
  }
}
