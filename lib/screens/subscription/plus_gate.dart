import 'package:flutter/material.dart';

import '../../repositories/plus_funnel_repository.dart';
import '../../services/analytics/analytics.dart';
import '../../state/app_controller.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import 'calonavi_plus_flow.dart';

/// サーバが購入を確認できなかったとき。行き止まりにせず、同じ確認から課金画面へ進む。
const plusPurchaseUnconfirmedMessage =
    'カロナビ+の購入を確認できませんでした。購入済みの場合は次の画面で「購入を復元」を押してください。';

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
  await presentCalonaviPlusDialog(
    context,
    controller,
    message: message,
    feature: feature,
  );
  return controller.subscriptionRepository.isPlusActive;
}

/// 端末が有料でも、サーバが `not_plus` のときは確認ダイアログから課金画面を開く。
Future<void> promptServerPlusRejected(
  BuildContext context,
  AppController controller, {
  PlusFunnelFeature? feature,
}) {
  return presentCalonaviPlusDialog(
    context,
    controller,
    message: plusPurchaseUnconfirmedMessage,
    feature: feature,
    ignoreCurrentPlus: true,
  );
}

/// 「こちらは有料の機能です」の確認。進むと課金画面（購入を復元あり）を開く。
Future<void> presentCalonaviPlusDialog(
  BuildContext context,
  AppController controller, {
  required String message,
  PlusFunnelFeature? feature,
  bool ignoreCurrentPlus = false,
}) async {
  if (!ignoreCurrentPlus && controller.subscriptionRepository.isPlusActive) {
    return;
  }
  if (!context.mounted) {
    return;
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
        onPlusActive: controller.syncPlusEntitlementToServer,
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
}
