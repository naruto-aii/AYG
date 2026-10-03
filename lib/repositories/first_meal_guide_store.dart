import 'package:shared_preferences/shared_preferences.dart';

/// 初回の食事案内を一度見せたあとに、同じ端末で再表示しない。
///
/// 設定テーブルには列を足さない。戻すときはこのキーを消す。
class FirstMealGuideStore {
  const FirstMealGuideStore();

  static const seenKey = 'ayg.first_meal_guide_seen';

  Future<bool> isSeen() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(seenKey) ?? false;
  }

  Future<void> markSeen() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(seenKey, true);
  }
}
