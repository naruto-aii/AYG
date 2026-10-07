import '../models/activity_level.dart';
import '../models/display_name.dart';
import '../models/goal.dart';

/// Version 1.1 ユーザー向け表示文字列（日本語）。
class AppStrings {
  AppStrings._();

  static const appTitle = 'カロナビ';

  /// 有料案内に出す Siri の話し方。この2文だけ。
  static const siriVoiceFoodPhrase =
      '食事：Hey Siri、カロナビで、食事にささみを300グラム。登録した内容を読み上げます。';
  static const siriVoiceExercisePhrase =
      '運動：Hey Siri、カロナビで、運動にジョギングを30分。「さっきの登録を取り消して」で直前を消せます。';
  static const siriVoicePaidGuidance =
      '$siriVoiceFoodPhrase\n$siriVoiceExercisePhrase';

  static const loginTagline = '毎日の食事と運動を、やさしく見える化。';

  /// ログイン画面のタグライン（Figma のとおり2行で表示）。
  static const loginTaglineMultiline = '毎日の食事と運動を、\nやさしく見える化。';

  /// ログイン画面の説明文（Figma のとおり3行で表示）。
  static const loginDescription =
      'がんばりすぎず、つづけられる。\nカロナビは、あなたの健康な毎日を\nやさしくサポートします。';

  static const loginWithGoogle = 'Googleでログイン';
  static const loginWithApple = 'Appleでログイン';

  /// 暫定アプリアイコン内の表示文字（正式アセット確定まで）。
  static const provisionalAppIconText = 'カ';

  static const navHome = 'ホーム';
  static const navFood = '食事';
  static const navWorkout = '運動';
  static const navWeight = '体重';
  static const navSettings = '設定';

  static const settingsTitle = '設定';
  static const settingsBasicInfo = '基本情報';
  static const settingsGoal = '目標設定';
  static const settingsHealthActivity = '活動・ヘルスケア';
  static const settingsFoodMaster = 'マイ食品';
  static const settingsAccount = 'アカウント';
  static const settingsLogout = 'ログアウト';
  static const settingsLoggedInAs = 'ログイン中';
  static const settingsContactOperator = '運営連絡';
  static const settingsSupport = 'サポート';
  static const settingsTokushoho = '特定商取引法に基づく表記';
  static const settingsAccountDeletion = 'アカウント削除';
  static const settingsAccountDeletionSubtitle = '公開食品は残ります。アプリ内で確認できます';
  static const accountDeletionLead = '削除するとログインできなくなります。公開食品は残ります。';
  static const accountDeletionRemoves = '削除されるもの';
  static const accountDeletionRemovesBody =
      '食事・運動・体重の記録、非公開の保存食品、テンプレート、プロフィール、目標、Health のワークアウト、検索語、画面の操作、カロナビ+の購入状態';
  static const accountDeletionKeeps = '残るもの';
  static const accountDeletionKeepsBody = '公開食品。氏名やメールアドレスは載せません。';
  static const accountDeletionBilling =
      'アカウントを削除しても、ストアの定期購入は止まりません。先に iPhone の「設定」> Apple ID >「サブスクリプション」で解約してください。';
  static const accountDeletionExecute = '削除する';
  static const accountDeletionReadPolicy = 'アカウント削除の説明';
  static const accountDeletionConfirmTitle = 'アカウントを削除しますか';
  static const accountDeletionConfirmBody =
      '個人の記録を削除します。公開食品は残ります。この操作は取り消せません。';
  static const accountDeletionFailed = 'アカウントを削除できませんでした';
  static const accountDeletionUnavailable =
      'いまアカウントを削除できません。時間をおくか、運営へメールしてください。';
  static const accountDeletionMailSubject = 'アカウント削除';
  static const accountDeletionAppleRevokeFailedTitle = 'Appleの連携を確認してください';
  static const accountDeletionAppleRevokeFailed =
      'アカウントは削除しました。Appleのサインインの解除に失敗したので、Apple IDの「サインインとセキュリティ」からカロナビを削除してください。';
  static const accountDeletionAppleRevokeFailedClose = '閉じる';
  static const plusBillingPeriod =
      '月額は1か月、半年は6か月、年額は1年の定期購入です。価格は選んだプランに出る、ストアの税込価格だけを使います。';
  static const plusHeroSubtitle = 'テンプレートの上限をなくし、ウィジェットとSiriで記録をもっと速く。';

  /// 既存の見出しの下に足す。ウィジェットと Siri の文は置き換えない。
  static const plusBetaAccessLead = 'β版機能への先行アクセスも付きます。';
  static const plusBetaAccessTitle = 'β版機能への先行アクセス';
  static const plusBetaAccessBody =
      '今日のコーチ (β) など、β版として先行公開している機能を使えます。';
  static const siriBetaNotice =
      '音声登録 (β) は、β版として先行公開している機能です。カロナビ+で使えます。';
  static const coachBetaNotice =
      '今日のコーチ (β) は、β版として先行公開している機能です。カロナビ+で使えます。';
  static const plusBenefitTemplateTitle = '食事・運動テンプレートが無制限';
  static const plusBenefitTemplateBody =
      '無料は食事・運動それぞれ4件まで。カロナビ+なら、いくつでも保存できます。';
  static const plusBenefitNoteTitle = '食事・運動の記録にメモを追加';
  static const plusBenefitNoteBody = '無料ではメモは使えません。カロナビ+なら、食事にも運動にもメモを残せます。';
  static const plusBenefitWidgetTitle = 'ホーム画面とロック画面からワンタップ記録';
  static const plusBenefitWidgetBody =
      '残りカロリーに加え、アプリを開かずに、食事テンプレート3種類と運動テンプレート2件を、いつでもウィジェットから登録できます。';
  static const plusBenefitSiriTitle = 'Siri (β) に話しかけるだけで記録';
  static const plusBenefitSiriBody = '食事も運動も、声で登録できます。';
  static const plusCtaPrefix = 'で始める';
  static const plusBadgeBestValue = '一番お得';
  static const plusBadgeSave = 'お得';

  /// 月額580円との比較。半年は 2,900÷6≒483 で「お得」、年額は 5,400÷12=450 で「一番お得」。
  static const plusHalfYearNote = '月あたり約483円';
  static const plusYearlyNote = '月あたり450円';
  static const plusMonthlyNote = 'いつでも解約できます';

  /// 課金画面に出す決定価格。ストアが別の金額を返しても、この金額を出す。購入処理には渡さない。
  static const plusFallbackMonthlyPrice = '¥580';
  static const plusFallbackHalfYearPrice = '¥2,900';
  static const plusFallbackYearlyPrice = '¥5,400';
  static const plusAutoRenew = '期限が来る前に解約しないと、同じ期間で自動更新されます。';
  static const plusCancelHow =
      '解約は iPhone の「設定」> Apple ID >「サブスクリプション」から行えます。アプリを消しても課金は止まりません。';
  static const plusCurrentExpiryPrefix = '現在の有効期限';
  static const loginLegalAgreement = 'ログインにより、利用規約とプライバシーポリシーに同意したものとします。';

  /// ログイン画面の同意文言（Figma のとおり2行で固定表示）。
  /// 端末ごとに折り返し位置が変わらないよう、改行位置を明示する。
  static const loginLegalAgreementMultiline =
      'ログインにより、利用規約とプライバシーポリシーに\n同意したものとします。';

  static const displayName = 'ユーザー名';
  static const displayNameHint = '表示する名前';
  static const displayNameRequired = 'ユーザー名を入力してください';
  static const displayNameTooLong = 'ユーザー名は40文字以内で入力してください';
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
  static const webHealthUnavailable = 'このプレビューでは Health 連携は利用できません。';

  static const save = '保存';
  static const cancel = 'キャンセル';
  static const delete = '削除';
  static const next = '次へ';
  static const notSelected = '未選択';

  static const macroProtein = 'タンパク質';
  static const macroCarb = '炭水化物';
  static const macroFat = '脂質';
  static const macroKcal = 'カロリー';

  static const macroNutrientsRequired = 'カロリー・タンパク質・脂質・炭水化物はすべて必須です';
  static const macroNutrientsRequiredShort = 'カロリー・タンパク質・脂質・炭水化物は必須です';
  static const macroManualConsistencyRequired =
      '手入力食品は カロリー = タンパク質×4 + 脂質×9 + 炭水化物×4 に整合している必要があります';
  static const macroExternalMismatchTitle = '表示カロリーと栄養素換算値が異なる場合があります。';
  static const macroDisplayedKcalLabel = '表示カロリー';
  static const macroDerivedKcalLabel = '栄養素換算';
  static const macroExternalMismatchFootnote =
      '食物繊維・糖アルコール・有機酸・表示丸め等により一致しない場合があります。';
  static const macroIntakePreviewPrefix = '今回の摂取';
  static const macroNutritionInfoLabel = '栄養情報';
  static const macroRecordNutritionLabel = '記録する栄養';
  static const quantityLabel = '数量';
  static const remainingToday = '今日あと';
  static const remainingKcalSuffix = '食べられます';

  static const weightSourceManual = '手入力';
  static const weightSourceHealth = 'Healthから取得';
  static const weightSourceHealthPending = 'Health（未取得）';
  static const weightManualOverwriteNotice =
      '手入力と Health のうち、測定時刻が新しい方を計算に使います。連携中でも、アプリの記録の方が新しければそちらです。';

  static const goalWarningLoseAboveCurrent = '減量なのに目標体重が現在体重以上です。';
  static const goalWarningGainBelowCurrent = '増量なのに目標体重が現在体重以下です。';
  static const goalWarningShortPeriod = '目標日までの期間が短い可能性があります。';
  static const goalWarningMaintainMismatch = '維持なのに目標体重と現在体重に差があります。';
  static const goalWarningTitle = '目標設定の確認';

  static String activityLevelLabel(ActivityLevel level) => level.everydayLabel;

  static String activityLevelDescription(ActivityLevel level) =>
      level.everydayDescription;

  static String goalTypeLabel(GoalType type) => type.label;
}

String? displayNameValidationMessage(String raw) {
  return switch (DisplayName.validate(raw)) {
    DisplayNameError.empty => AppStrings.displayNameRequired,
    DisplayNameError.tooLong => AppStrings.displayNameTooLong,
    null => null,
  };
}
