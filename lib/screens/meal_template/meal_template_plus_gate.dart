import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../repositories/plus_funnel_repository.dart';
import '../../repositories/subscription_exceptions.dart';
import '../../state/app_controller.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../subscription/calonavi_plus_flow.dart';

/// 無料は4件まで。カロナビ+は何件でも作れる。作ってよいときは true。
Future<bool> allowMealTemplateCreate(
  BuildContext context,
  AppController controller,
) async {
  if (await controller.canCreateMealTemplate()) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  controller.recordPlusFunnel(
    event: PlusFunnelEvent.gateShown,
    feature: PlusFunnelFeature.mealTemplateLimit,
  );
  final openPlus = await showAppConfirmDialog(
    context: context,
    title: AppStrings.plusGateTitle,
    message: SubscriptionLimitExceededException(
      SubscriptionLimitKind.mealTemplate,
    ).toString(),
    confirmLabel: 'カロナビ+を見る',
    cancelLabel: '閉じる',
  );
  if (openPlus == true && context.mounted) {
    controller.recordPlusFunnel(
      event: PlusFunnelEvent.gateTap,
      feature: PlusFunnelFeature.mealTemplateLimit,
    );
    final custom = controller.openCalonaviPlusFlow;
    if (custom != null) {
      await custom(context);
    } else {
      await showCalonaviPlus(
        context,
        repository: controller.subscriptionRepository,
        feature: PlusFunnelFeature.mealTemplateLimit,
        funnel: controller.plusFunnelRepository,
        onPlusActive: controller.syncPlusEntitlementToServer,
      );
    }
  }
  return false;
}
