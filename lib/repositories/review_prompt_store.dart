import 'package:shared_preferences/shared_preferences.dart';

/// レビュー依頼を出したか、断ったか。評価や本文は保存しない。
abstract class ReviewPromptStore {
  Future<bool> isClosed();

  Future<bool> hasDue();

  /// 新しく依頼が必要になったときだけ true。閉じたあとは false。
  Future<bool> markDue({required bool streak, required bool external});

  Future<void> markDeclined();

  Future<void> markAsked();
}

class NoOpReviewPromptStore implements ReviewPromptStore {
  const NoOpReviewPromptStore();

  @override
  Future<bool> isClosed() async => true;

  @override
  Future<bool> hasDue() async => false;

  @override
  Future<bool> markDue({required bool streak, required bool external}) async {
    return false;
  }

  @override
  Future<void> markDeclined() async {}

  @override
  Future<void> markAsked() async {}
}

class PreferencesReviewPromptStore implements ReviewPromptStore {
  PreferencesReviewPromptStore({this.preferences});

  static const declinedKey = 'review_prompt_declined_v1';
  static const askedKey = 'review_prompt_asked_v1';
  static const streakDueKey = 'review_prompt_streak_due_v1';
  static const externalDueKey = 'review_prompt_external_due_v1';

  final SharedPreferences? preferences;

  @override
  Future<bool> isClosed() async {
    try {
      final prefs = await _prefs();
      return prefs.getBool(declinedKey) == true ||
          prefs.getBool(askedKey) == true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> hasDue() async {
    if (await isClosed()) {
      return false;
    }
    try {
      final prefs = await _prefs();
      return prefs.getBool(streakDueKey) == true ||
          prefs.getBool(externalDueKey) == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> markDue({required bool streak, required bool external}) async {
    if ((!streak && !external) || await isClosed()) {
      return false;
    }
    try {
      final prefs = await _prefs();
      final wasDue =
          prefs.getBool(streakDueKey) == true ||
          prefs.getBool(externalDueKey) == true;
      if (streak) {
        await prefs.setBool(streakDueKey, true);
      }
      if (external) {
        await prefs.setBool(externalDueKey, true);
      }
      return !wasDue;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> markDeclined() async {
    await _close(declinedKey);
  }

  @override
  Future<void> markAsked() async {
    await _close(askedKey);
  }

  Future<void> _close(String key) async {
    try {
      final prefs = await _prefs();
      await prefs.setBool(key, true);
      await prefs.setBool(streakDueKey, false);
      await prefs.setBool(externalDueKey, false);
    } catch (_) {
      return;
    }
  }

  Future<SharedPreferences> _prefs() async {
    return preferences ?? await SharedPreferences.getInstance();
  }
}
