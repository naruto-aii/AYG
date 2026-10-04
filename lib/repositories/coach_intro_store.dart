import 'package:shared_preferences/shared_preferences.dart';

/// コーチを初めて開いたときの案内を、同じ端末では一度だけ出す。
abstract class CoachIntroStore {
  Future<bool> hasSeen();
  Future<void> markSeen();
}

class PreferencesCoachIntroStore implements CoachIntroStore {
  PreferencesCoachIntroStore({this.preferences});

  static const storageKey = 'coach_intro_seen_v1';

  final SharedPreferences? preferences;

  @override
  Future<bool> hasSeen() async {
    try {
      return (await _prefs()).getBool(storageKey) ?? false;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> markSeen() async {
    try {
      await (await _prefs()).setBool(storageKey, true);
    } catch (_) {
      return;
    }
  }

  Future<SharedPreferences> _prefs() async {
    return preferences ?? await SharedPreferences.getInstance();
  }
}
