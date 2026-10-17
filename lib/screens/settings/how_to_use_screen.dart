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
      featureName: '食事の提案',
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
                        'ウィジェットは、残りカロリーに加え、アプリを開かずに食事と運動を登録します。枠は食事と運動を自由に組み合わせられます。カロナビ+です。',
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
        label: '食事の提案',
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
            subtitle: 'やりたいことから、その画面を開きます。',
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
