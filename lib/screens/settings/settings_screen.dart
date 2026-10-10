import 'package:flutter/material.dart';

import '../../config/app_contact_config.dart';
import '../../config/official_foods_flag.dart';
import '../../constants/app_strings.dart';
import '../../repositories/authentication_repository.dart';
import '../../repositories/plus_funnel_repository.dart';
import '../../repositories/health_repository.dart';
import '../../services/analytics/catalog_actions.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/settings_row.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../coach/daily_coach_screen.dart';
import '../subscription/calonavi_plus_flow.dart';
import '../subscription/plus_gate.dart';
import 'how_to_use_screen.dart';
import 'lock_screen_meal_screen.dart';
import 'operator_contact_screen.dart';
import 'siri_voice_setup_screen.dart';
import 'settings_account_screen.dart';
import 'settings_food_master_screen.dart';
import 'settings_health_activity_screen.dart';
import 'settings_policies_screen.dart';
import 'settings_profile_screen.dart';
import 'settings_reference_screen.dart';

/// 設定。
///
/// Figma: SP / 10 設定（24:345）
///
/// 計算とデータの出典、規約3件、ログアウトとアカウント削除は
/// それぞれ1行にまとめ、中の画面で従来どおり開ける。
/// 問い合わせは「運営連絡」にまとめてある。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.authenticationRepository,
    this.healthRepository,
    this.openFoodFactsService,
    this.hideHealthSettings = false,
    this.showLockScreenMeal = false,
    this.supportEmail,
  });

  final AppController controller;
  final AuthenticationRepository authenticationRepository;
  final HealthRepository? healthRepository;
  final OpenFoodFactsService? openFoodFactsService;
  final bool hideHealthSettings;

  /// iOS 17 以降のウィジェットと音声登録。Web と Android では出さない。
  final bool showLockScreenMeal;
  final String? supportEmail;

  static const double _rowGap = 8;

  Future<void> _openPersonalCoach(BuildContext context) async {
    final allowed = await ensureCalonaviPlus(
      context,
      controller,
      message: AppStrings.coachBetaNotice,
      feature: PlusFunnelFeature.coach,
    );
    if (!allowed || !context.mounted) {
      return;
    }
    await Navigator.of(context).push<CoachSavedKind>(
      MaterialPageRoute<CoachSavedKind>(
      settings: const RouteSettings(name: 'settings_screen_MaterialPageRoute_0'),
        builder: (context) => DailyCoachScreen(controller: controller),
      ),
    );
  }

  Future<void> _openMealWidget(BuildContext context) async {
    final paid = await controller.ensurePaidShortcutsReady();
    if (!context.mounted) {
      return;
    }
    if (!paid) {
      controller.recordPlusFunnel(
        event: PlusFunnelEvent.gateShown,
        feature: PlusFunnelFeature.widget,
      );
      final openPlus = await showAppConfirmDialog(
        context: context,
        title: AppStrings.plusGateTitle,
        message:
            'ホーム画面とロック画面のウィジェットから、アプリを開かずに食事と運動を登録します。枠は食事と運動を自由に組み合わせられます。カロナビ+です。',
        confirmLabel: 'カロナビ+を見る',
        cancelLabel: '閉じる',
      );
      if (openPlus == true && context.mounted) {
        controller.recordPlusFunnel(
          event: PlusFunnelEvent.gateTap,
          feature: PlusFunnelFeature.widget,
        );
        await _openCalonaviPlus(context, feature: PlusFunnelFeature.widget);
      }
      return;
    }
    _push(context, LockScreenMealScreen(controller: controller));
  }

  /// 音声登録。未加入だけ購入画面へ進む。加入中はショートカットの使い方を出す。
  Future<void> _openVoiceRegistration(BuildContext context) async {
    final paid = await controller.ensurePaidShortcutsReady();
    if (!context.mounted) {
      return;
    }
    if (!paid) {
      controller.recordPlusFunnel(
        event: PlusFunnelEvent.gateShown,
        feature: PlusFunnelFeature.siri,
      );
      final openPlus = await showAppConfirmDialog(
        context: context,
        title: AppStrings.plusGateTitle,
        message:
            AppStrings.siriVoicePaidGuidance,
        confirmLabel: 'カロナビ+を見る',
        cancelLabel: '閉じる',
      );
      if (openPlus != true || !context.mounted) {
        return;
      }
      controller.recordPlusFunnel(
        event: PlusFunnelEvent.gateTap,
        feature: PlusFunnelFeature.siri,
      );
      await _openCalonaviPlus(context, feature: PlusFunnelFeature.siri);
      return;
    }
    _push(context, const SiriVoiceSetupScreen());
  }

  Future<void> _clearTestPurchase(BuildContext context) async {
    await controller.subscriptionRepository.clearTestPurchase();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('無料に戻しました')));
  }

  Future<void> _openCalonaviPlus(
    BuildContext context, {
    PlusFunnelFeature? feature,
  }) async {
    final custom = controller.openCalonaviPlusFlow;
    if (custom != null) {
      await custom(context);
      return;
    }
    await showCalonaviPlus(
      context,
      repository: controller.subscriptionRepository,
      feature: feature,
      funnel: controller.plusFunnelRepository,
      onPlusActive: controller.syncPlusEntitlementToServer,
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'settings_screen_MaterialPageRoute_1'),builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final email = authenticationRepository.currentUser?.email;
    final contactEmail = (supportEmail ?? AppContactConfig.contactEmail).trim();
    final health = healthRepository;

    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Text('設定', style: AppTypography.headingL),
          const SizedBox(height: 4),
          Text(
            'あなたに合った使い方で、\nカロナビをもっと便利に。',
            style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          SettingsRow(
            icon: AppIcons.user,
            title: 'ログイン中',
            subtitle: email ?? 'アカウント情報の確認・変更',
            showChevron: false,
          ),
          if (controller.subscriptionRepository.testPurchaseToggleEnabled) ...[
            const SizedBox(height: _rowGap),
            SettingsRow(
              key: const Key('test-purchase-revert'),
              icon: AppIcons.information,
              title: 'テスト用: 無料に戻す',
              subtitle: controller.subscriptionRepository.isPlusActive
                  ? '今はカロナビ+です。押すとすぐに無料になります'
                  : '今は無料です。カロナビ+の購入ボタンでカロナビ+に戻します',
              onTap: () => _clearTestPurchase(context),
            ),
          ],
          const SizedBox(height: _rowGap),
          SettingsRow(
            icon: AppIcons.information,
            title: '使い方',
            subtitle: 'はじめての操作と、無料との違い',
            onTap: () => _push(context, const HowToUseScreen()),
          ),
          const SizedBox(height: _rowGap),
          SettingsRow(
            key: const Key('settings-personal-coach'),
            icon: AppIcons.meal,
            title: 'パーソナルコーチ (β)',
            subtitle: '食事と自炊の献立を提案',
            onTap: () => _openPersonalCoach(context),
          ),
          const SizedBox(height: _rowGap),
          SettingsRow(
            key: const Key('settings-profile'),
            icon: AppIcons.human,
            title: 'プロフィールと目標',
            subtitle: '名前・体格と、目標カロリー',
            onTap: () => _push(
              context,
              SettingsProfileScreen(
                controller: controller,
                authenticationRepository: authenticationRepository,
              ),
            ),
          ),
          const SizedBox(height: _rowGap),
          SettingsRow(
            icon: AppIcons.exercise,
            title: '活動・Health',
            subtitle: hideHealthSettings
                ? AppStrings.webHealthUnavailable
                : '運動・歩数・ヘルスケア連携の設定',
            onTap: hideHealthSettings || health == null
                ? null
                : () => _push(
                    context,
                    SettingsHealthActivityScreen(
                      controller: controller,
                      healthRepository: health,
                    ),
                  ),
          ),
          const SizedBox(height: _rowGap),
          SettingsRow(
            icon: AppIcons.meal,
            title: '保存済み食品',
            subtitle: '保存済み食品の登録・管理',
            onTap: () => _push(
              context,
              SettingsFoodMasterScreen(
                controller: controller,
                openFoodFactsService: openFoodFactsService,
              ),
            ),
          ),
          if (showLockScreenMeal) ...[
            const SizedBox(height: _rowGap),
            SettingsRow(
              icon: AppIcons.template,
              title: 'ウィジェット',
              subtitle: 'ホーム画面とロック画面から登録',
              onTap: () => _openMealWidget(context),
            ),
            const SizedBox(height: _rowGap),
            SettingsRow(
              icon: AppIcons.information,
              title: '音声登録 (β)',
              subtitle: '声だけで食事・運動を登録',
              onTap: () => _openVoiceRegistration(context),
            ),
          ],
          const SizedBox(height: _rowGap),
          SettingsRow(
            key: const Key('settings-references'),
            icon: AppIcons.calculator,
            title: '計算とデータについて',
            subtitle: OfficialFoodsFlag.enabled
                ? '算出方法と食品データの出典'
                : 'カロリーと栄養素の算出方法',
            onTap: () => _push(context, const SettingsReferenceScreen()),
          ),
          const SizedBox(height: _rowGap),
          SettingsRow(
            key: const Key('settings-policies'),
            icon: AppIcons.document,
            title: '規約とポリシー',
            subtitle: '利用規約、プライバシー、特商法',
            onTap: () => _push(context, const SettingsPoliciesScreen()),
          ),
          if (contactEmail.isNotEmpty) ...[
            const SizedBox(height: _rowGap),
            SettingsRow(
              icon: AppIcons.mail,
              title: AppStrings.settingsContactOperator,
              subtitle: contactEmail,
              onTap: () {
                CatalogActions.contactTap('settings');
                _push(context, OperatorContactScreen(email: contactEmail));
              },
            ),
          ],
          const SizedBox(height: _rowGap),
          SettingsRow(
            key: const Key('settings-account'),
            icon: AppIcons.user,
            title: 'アカウント',
            subtitle: 'ログアウトとアカウント削除',
            onTap: () => _push(
              context,
              SettingsAccountScreen(
                controller: controller,
                authenticationRepository: authenticationRepository,
                supportEmail: supportEmail,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
