import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/open_food_facts_config.dart';
import '../../constants/app_strings.dart';
import '../../repositories/authentication_repository.dart';
import '../../repositories/health_repository.dart';
import '../../repositories/plus_funnel_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_page.dart';
import '../coach/daily_coach_screen.dart';
import '../exercise/exercise_form_screen.dart';
import '../food/food_form_navigation.dart';
import '../history/history_calendar_screen.dart';
import '../subscription/calonavi_plus_flow.dart';
import '../subscription/plus_gate.dart';
import '../weight/weight_record_screen.dart';
import 'lock_screen_meal_screen.dart';
import 'operator_contact_screen.dart';
import 'settings_basic_info_screen.dart';
import 'settings_food_master_screen.dart';
import 'settings_goal_screen.dart';
import 'settings_health_activity_screen.dart';
import 'settings_reference_screen.dart';
import 'siri_voice_setup_screen.dart';

/// 設定の「使い方」。やりたいことから、いまある画面を開く。
///
/// ホームの「？」は controller を渡さない。そのときは行き先が決まらない
/// ボタンを押せないようにする。設定からは controller を渡す。
class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({
    super.key,
    this.controller,
    this.openFoodFactsService,
    this.authenticationRepository,
    this.healthRepository,
    this.hideHealthSettings = false,
    this.showLockScreenMeal = false,
    this.supportEmail,
  });

  final AppController? controller;
  final OpenFoodFactsService? openFoodFactsService;
  final AuthenticationRepository? authenticationRepository;
  final HealthRepository? healthRepository;
  final bool hideHealthSettings;
  final bool showLockScreenMeal;
  final String? supportEmail;

  OpenFoodFactsService _foods() {
    return openFoodFactsService ??
        OpenFoodFactsService(userAgent: OpenFoodFactsConfig.userAgent);
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(
          name: 'how_to_use_screen_MaterialPageRoute_0',
        ),
        builder: (context) => screen,
      ),
    );
  }

  Future<void> _openPaidScreen(
    BuildContext context, {
    required PlusFunnelFeature feature,
    required String featureName,
    required String message,
    required Widget screen,
  }) async {
    final controller = this.controller;
    if (controller == null) {
      return;
    }
    final paid = await controller.ensurePaidShortcutsReady();
    if (!context.mounted) {
      return;
    }
    if (!paid) {
      controller.recordPlusFunnel(
        event: PlusFunnelEvent.gateShown,
        feature: feature,
      );
      final openPlus = await showAppConfirmDialog(
        context: context,
        title: calonaviPlusGateTitle(featureName),
        message: withCalonaviPlusFreeForever(message),
        confirmLabel: 'カロナビ+を見る',
        cancelLabel: '閉じる',
      );
      if (openPlus == true && context.mounted) {
        controller.recordPlusFunnel(
          event: PlusFunnelEvent.gateTap,
          feature: feature,
        );
        final custom = controller.openCalonaviPlusFlow;
        if (custom != null) {
          await custom(context);
        } else {
          await showCalonaviPlus(
            context,
            repository: controller.subscriptionRepository,
            feature: feature,
            funnel: controller.plusFunnelRepository,
            onPlusActive: controller.syncPlusEntitlementToServer,
          );
        }
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    _push(context, screen);
  }

  Future<void> _openCoach(BuildContext context) async {
    final controller = this.controller;
    if (controller == null) {
      return;
    }
    final allowed = await ensureCalonaviPlus(
      context,
      controller,
      message: AppStrings.coachBetaNotice,
      feature: PlusFunnelFeature.coach,
      featureName: 'パーソナルコーチ',
    );
    if (!allowed || !context.mounted) {
      return;
    }
    _push(context, DailyCoachScreen(controller: controller));
  }

  List<_HowToLink> _links(BuildContext context) {
    final controller = this.controller;
    final health = healthRepository;
    final email = supportEmail?.trim() ?? '';
    return [
      _HowToLink(
        label: '食事を記録する',
        buttonKey: const Key('how-to-open-food'),
        onOpen: controller == null
            ? null
            : () => openFoodFormScreen(
                context,
                controller: controller,
                openFoodFactsService: _foods(),
              ),
      ),
      _HowToLink(
        label: '運動を記録する',
        buttonKey: const Key('how-to-open-exercise'),
        onOpen: controller == null
            ? null
            : () => _push(
                context,
                ExerciseFormScreen(controller: controller),
              ),
      ),
      _HowToLink(
        label: '体重を記録する',
        buttonKey: const Key('how-to-open-weight'),
        onOpen: controller == null
            ? null
            : () => _push(
                context,
                WeightRecordScreen(controller: controller),
              ),
      ),
      _HowToLink(
        label: '記録を見る',
        buttonKey: const Key('how-to-open-history'),
        onOpen: controller == null
            ? null
            : () => _push(
                context,
                HistoryCalendarScreen(
                  controller: controller,
                  openFoodFactsService: _foods(),
                ),
              ),
      ),
      _HowToLink(
        label: '目標を決める',
        buttonKey: const Key('how-to-open-goal'),
        onOpen: controller == null
            ? null
            : () => _push(
                context,
                SettingsGoalScreen(controller: controller),
              ),
      ),
      _HowToLink(
        label: '基本情報を変える',
        buttonKey: const Key('how-to-open-basic-info'),
        onOpen: controller == null
            ? null
            : () => _push(
                context,
                SettingsBasicInfoScreen(
                  controller: controller,
                  suggestedDisplayName: authenticationRepository
                      ?.currentUser
                      ?.suggestedDisplayName,
                ),
              ),
      ),
      _HowToLink(
        label: '自分の食品とテンプレート',
        buttonKey: const Key('how-to-open-foods'),
        onOpen: controller == null
            ? null
            : () => _push(
                context,
                SettingsFoodMasterScreen(
                  controller: controller,
                  openFoodFactsService: openFoodFactsService,
                ),
              ),
      ),
      if (health != null && !hideHealthSettings)
        _HowToLink(
          label: 'ヘルスケア連携',
          buttonKey: const Key('how-to-open-health'),
          onOpen: controller == null
              ? null
              : () => _push(
                  context,
                  SettingsHealthActivityScreen(
                    controller: controller,
                    healthRepository: health,
                  ),
                ),
        ),
      if (showLockScreenMeal)
        _HowToLink(
          label: 'ウィジェット',
          buttonKey: const Key('how-to-open-widget'),
          onOpen: controller == null
              ? null
              : () => unawaited(
                  _openPaidScreen(
                    context,
                    feature: PlusFunnelFeature.widget,
                    featureName: 'ウィジェット',
                    message:
                        'ホーム画面とロック画面のウィジェットから、アプリを開かずに食事と運動を登録します。枠は食事と運動を自由に組み合わせられます。カロナビ+です。',
                    screen: LockScreenMealScreen(controller: controller),
                  ),
                ),
        ),
      if (showLockScreenMeal)
        _HowToLink(
          label: '音声登録',
          buttonKey: const Key('how-to-open-voice'),
          onOpen: controller == null
              ? null
              : () => unawaited(
                  _openPaidScreen(
                    context,
                    feature: PlusFunnelFeature.siri,
                    featureName: '音声登録',
                    message: AppStrings.siriVoicePaidGuidance,
                    screen: const SiriVoiceSetupScreen(),
                  ),
                ),
        ),
      _HowToLink(
        label: 'パーソナルコーチ',
        buttonKey: const Key('how-to-open-coach'),
        onOpen: controller == null
            ? null
            : () => unawaited(_openCoach(context)),
      ),
      _HowToLink(
        label: '計算の見方',
        buttonKey: const Key('how-to-open-calculation'),
        onOpen: () => _push(context, const SettingsReferenceScreen()),
      ),
      if (email.isNotEmpty)
        _HowToLink(
          label: 'お問い合わせ',
          buttonKey: const Key('how-to-open-contact'),
          onOpen: () => _push(
            context,
            OperatorContactScreen(email: email),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final links = _links(context);
    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: '使い方',
            subtitle: 'はじめての操作と、無料とカロナビ+の違いです。',
          ),
          DesignCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Section(
                  title: '食事を記録する',
                  body:
                      'ホームの「食事追加」か、下の「食事」にある「食事を追加」から、食品名と量を入れて保存します。保存した食事は、その日の「今日の食事」に出ます。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: '残りのカロリー',
                  body:
                      'ホームの「今日あと」は、その日の食事目標から、食べた分を引いた残りです。運動を記録すると、その消費が残りに足されます。目標を超えると「超過」と出ます。iPhoneでヘルスケア連携を使っているときは、生活活動として見込んだ分を超えた活動量も残りに足します。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: '目標を決める',
                  body:
                      '設定の「プロフィールと目標」にある「目標設定」で、減量・維持・増量と、目標体重、目標日を保存します。1日のカロリーは自動で計算するか、自分でカロリーと、たんぱく質・脂質・炭水化物を入れます。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: '運動を記録する',
                  body:
                      'ホームの「運動追加」か、下の「運動」から記録します。種目を選ぶと、時間や距離から消費カロリーを計算できるものがあります。計算しない種目は、カロリーを自分で入れます。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: 'ウィジェットと、音声登録',
                  body:
                      'ウィジェットでワンタップ記録は、ホーム画面とロック画面のウィジェットです。ホーム画面の大きなウィジェットは、残りカロリーに加え、アプリを開かずに食事と運動を登録します。枠は食事と運動を自由に組み合わせられます。ロック画面の3枠は、ホームの1〜3枠目を種類も含めてそのまま使います。枠の中身は、保存した食事・運動テンプレートを選んで食品や種目ごとに量を変えて入れるか、その場で作ります。枠に入れても元のテンプレートは変わらず、テンプレートの件数にも入りません。アプリの中で保存しただけでは、ホーム画面やロック画面に自動では付きません。ホーム画面は、いちばん左のページを長押しし、左上「編集」から「ウィジェットを追加」でカロナビを選びます。ロック画面は、長押しして「カスタマイズ」→「ロック画面」と進み、時刻の上下の枠をタップしてカロナビを選び、「完了」を押します。音声のショートカットは、自分で追加しません。使う前に、設定アプリの「Siriと検索」（または「Apple IntelligenceとSiri」）でSiriをオンにし、カロナビにログインしておきます。「Hey Siri、カロナビに登録」または「Hey Siri、カロナビ登録」と話し、Siriの短い質問に答えます。食事は「Hey Siri、カロナビで食事を記録」、運動は「Hey Siri、カロナビで運動を記録」です。質問には「ささみ100g」のように量まで答えられます。一覧にある食品は「Hey Siri、カロナビで食事にささみ」、運動は「Hey Siri、カロナビで運動にウォーキング」です。この言い方では量は続く質問に答えます。一覧に無いものは「カロナビで食事を記録」から話します。登録した内容を読み上げます。直前の1件は「Hey Siri、カロナビで今登録したやつ消して」で消せます。候補が分かれるときだけ、登録の前に確認します。牛ももの焼き200gのように詳しく答えると、その場で登録できます。牛肉のように種類が分かれると、部位を聞くことがあります。食事か運動か決まらないときは、どちらに登録するかを確認します。食品成分表と、ブロックしていない人の公開食品もSiriから登録できます。保存した食品とテンプレート名は、アプリを開いたあと「カロナビで食事に」のあとに言えます。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: '無料とカロナビ+',
                  body:
                      '無料でも、食事・運動・体重の記録、記録の共有、食事と運動のメモ、食事テンプレート4件、運動テンプレート4件が使えます。カロナビ+では食事と運動のテンプレートの件数制限がなくなり、直近3日の食品、ウィジェットでワンタップ記録、音声登録、写真で登録、外食・コンビニ、AIで探す、パーソナルコーチが使えます。Apple がその Apple ID にまだ無料期間を付けていないときは、どのプランも3日間無料で試せます。同じ Apple ID では1回です。無料期間中に購入すると、残りの無料期間は失効します。無料期間が終わる24時間以上前に解約しない限り、選んだプランの料金で自動更新されます。ウィジェットとSiriで、記録を速くできます。${AppStrings.plusAiDailyLimit}ウィジェットの置き方と音声の始め方は、上の節と各画面に書いてあります。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: 'テンプレート',
                  body:
                      '食事テンプレートは、よく食べる食品を一度に登録します。運動テンプレートは、よくする運動の組み合わせです。無料はそれぞれ4件までで、カロナビ+は何件でも保存できます。ウィジェットのボタンの中身は、この一覧から選んで量を変えて入れられます。入れても元のテンプレートは変わりません。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: 'メモ',
                  body: '食事と運動のメモは無料です。カロリーの計算には使いません。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: '運動のきつさ',
                  body:
                      '種目によっては、楽からきついまで選べます。同じ時間でも、きつさで消費カロリーが変わります。カロリーを自分で入れる種目には、きつさはありません。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: 'パーソナルコーチ',
                  body:
                      'ホームの「パーソナルコーチ」は、残りカロリーを時間帯に合わせて今日これからの食事と間食に分け、食事ごとに主食・主菜・副菜の組み合わせと量を提案します。11時までは朝食・昼食・間食・夕食、11時から15時までは昼食・間食・夕食、15時から22時までは夕食、22時以降は間食だけです。1食は850kcalまで、間食は乳製品や果物で1回200kcalまでです。画面の上に、今日の残りカロリーを食事ごとに何kcalずつ食べるかと、その合計を出します。食事ごとに食品とおすすめの量・kcalが並び、量を変えるとkcalも変わります。食べすぎた日は運動を提案します。「ほかの案」で次の案を見られます。食べた食事ごとに量を確認して登録し、登録するまで記録には入りません。登録した食事は次に開いたとき「登録済み」になり、新しい残りカロリーで、まだの食事を組み直します。同じ画面の「自炊コーチ」は、手元の食材とこの食事の目標から作る料理を2案出し、「これを作る」で食事に追加します。${AppStrings.plusAiDailyLimit}',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: 'お知らせ',
                  body: 'ホーム上部の「お知らせ」は、運営からの連絡です。赤い点は未読で、開くと既読になります。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: '体重',
                  body:
                      '体重の記録は、1日のカロリー計算に使います。手入力とヘルスケアは、測った時刻が新しい方です。7日より古いときは、画面が記録を促します。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: '記録を共有する',
                  body:
                      'ホーム右上の共有を押すと、今日の摂取カロリーが、目標に対する丸い進捗の画像で送れます。文章には、目標のうちどれだけ摂ったかと、アプリの紹介、リンクが入ります。送る相手は、iPhoneの共有で選びます。共有は無料です。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: '食品の探し方',
                  body:
                      '食事の追加は、写真で登録、検索、その他の3つです。検索は保存済み食品、定番の食品、公開食品です。その中に外食・コンビニと AIで探すがあります。その他は手入力、バーコード、テンプレートです。公開食品は、ほかの人が公開した食品で、氏名やメールは載りません。公開した食品は、アカウントを削除しても残ります。写真で登録はカロナビ+です。写真を撮るか、カメラロールから選びます。料理名は任意です。入れると精度が上がります。量も任意で、グラム・個数・杯数など、できるだけ正確に入れると精度が上がります。補足も任意で、油の量や脂身、ソースなど写真で分かりにくい特徴を書けます。カロリーとPFCはAIの推定です。登録の前に確認して、数値を直せます。料理名を入れなかったときは、登録のときに名前を確認します。写真はカロナビに保存しません。外食・コンビニと AIで探すもカロナビ+です。検索で見つからない食品は、チェーン店のメニューなども含めて、AIがカロリーとPFCの推定を出します。推定だと表示します。食品データベースには追加しません。${AppStrings.plusAiDailyLimit}',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: 'レビューのお願い',
                  body:
                      '7日続けて記録したあと、またはウィジェットか音声で登録したあとに出ることがあります。断ると次は出ません。評価の内容はアプリでは受け取りません。',
                ),
              ],
            ),
          ),
          for (var index = 0; index < links.length; index++) ...[
            if (index > 0) const SizedBox(height: AppSpacing.md),
            _HowToLinkView(link: links[index]),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.titleM),
        const SizedBox(height: AppSpacing.sm),
        Text(body, style: AppTypography.bodyS),
      ],
    );
  }
}

class _HowToLink {
  const _HowToLink({
    required this.label,
    required this.onOpen,
    required this.buttonKey,
  });

  final String label;
  final VoidCallback? onOpen;
  final Key buttonKey;
}

class _HowToLinkView extends StatelessWidget {
  const _HowToLinkView({required this.link});

  final _HowToLink link;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(link.label, style: AppTypography.titleM),
        const SizedBox(height: AppSpacing.sm),
        DesignButton(
          key: link.buttonKey,
          label: 'この画面を開く',
          style: DesignButtonStyle.outline,
          showTrailingIcon: false,
          height: 48,
          onPressed: link.onOpen,
        ),
      ],
    );
  }
}
