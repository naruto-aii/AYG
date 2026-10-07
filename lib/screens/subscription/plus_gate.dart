import 'package:flutter/material.dart';

import '../../repositories/plus_funnel_repository.dart';
import '../../services/analytics/analytics.dart';
import '../../state/app_controller.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import 'calonavi_plus_flow.dart';

/// カロナビ+が無い機能を止める。Siri とウィジェットの判定は呼ばない。
///
/// 案内の表示と「カロナビ+を見る」は記録する。送信に失敗しても操作は止めない。
Future<bool> ensureCalonaviPlus(
  BuildContext context,
  AppController controller, {
  required String message,
  PlusFunnelFeature? feature,
}) async {
  if (controller.subscriptionRepository.isPlusActive) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  controller.recordPlusFunnel(
    event: PlusFunnelEvent.gateShown,
    feature: feature,
  );
  final openPlus = await showAppConfirmDialog(
    context: context,
    title: 'こちらは有料の機能です',
    message: message,
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
  } else if (openPlus != true) {
    Analytics.emit('gate_tap', {
      'feature': feature == null
          ? 'other'
          : feature == PlusFunnelFeature.memo
          ? 'food_memo'
          : feature.storageValue,
      'choice': 'close',
    });
  }
  return controller.subscriptionRepository.isPlusActive;
}
