import '../models/activity_level.dart';
import '../models/goal.dart';

/// Version 1.1 ユーザー向け表示文字列（日本語）。
class AppStrings {
  AppStrings._();

  static const appTitle = 'AYG';

  static const navHome = 'ホーム';
  static const navFood = '食事';
  static const navWorkout = '運動';
  static const navWeight = '体重';
  static const navSettings = '設定';

  static const settingsTitle = '設定';
  static const settingsBasicInfo = '基本情報';
  static const settingsGoal = '目標設定';
  static const settingsHealthActivity = '活動・ヘルスケア';
  static const settingsAccount = 'アカウント';
  static const settingsLogout = 'ログアウト';
  static const settingsLoggedInAs = 'ログイン中';

  static const birthDate = '生年月日';
  static const gender = '性別';
  static const heightCm = '身長 (cm)';
  static const currentWeightKg = '現在体重 (kg)';
  static const goalType = '目標区分';
  static const targetWeightKg = '目標体重 (kg)';
  static const targetDate = '目標日';
  static const activityLevel = '活動量';
  static const healthIntegration = 'Health連携';
  static const healthResync = 'Healthから再取得';
  static const healthUsingActiveEnergy = 'Healthのアクティブエネルギーを使用中';
  static const healthUnavailableOnDevice = 'この端末では Health 連携に対応していません。';
  static const webHealthUnavailable = 'Web版では Health 連携は利用できません。';

  static const save = '保存';
  static const cancel = 'キャンセル';
  static const delete = '削除';
  static const next = '次へ';
  static const notSelected = '未選択';

  static const macroProtein = 'たんぱく質';
  static const macroCarb = '炭水化物';
  static const macroFat = '脂質';
  static const remainingToday = '今日あと';
  static const remainingKcalSuffix = '食べられます';

  static const weightSourceManual = '手入力';
  static const weightSourceHealth = 'Healthから取得';
  static const weightSourceHealthPending = 'Health（未取得）';
  static const weightManualOverwriteNotice =
      'Health連携中に手入力した体重は、再同期でHealthの値に更新される場合があります。';

  static const goalWarningLoseAboveCurrent = '減量なのに目標体重が現在体重以上です。';
  static const goalWarningGainBelowCurrent = '増量なのに目標体重が現在体重以下です。';
  static const goalWarningShortPeriod = '目標日までの期間が短い可能性があります。';
  static const goalWarningMaintainMismatch = '維持なのに目標体重と現在体重に差があります。';
  static const goalWarningTitle = '目標設定の確認';

  static String activityLevelLabel(ActivityLevel level) {
    return switch (level) {
      ActivityLevel.low => '低い',
      ActivityLevel.light => 'やや低い',
      ActivityLevel.moderate => '普通',
      ActivityLevel.high => '高い',
      ActivityLevel.veryHigh => '非常に高い',
    };
  }

  static String goalTypeLabel(GoalType type) => type.label;
}
