import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../repositories/plus_funnel_repository.dart';
import '../../services/analytics/analytics.dart';
import '../../state/app_controller.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import 'calonavi_plus_flow.dart';

/// サーバが購入を確認できなかったとき。行き止まりにせず、同じ確認から課金画面へ進む。
const plusPurchaseUnconfirmedMessage =
    'カロナビ+の購入を確認できませんでした。購入済みの場合は次の画面で「購入を復元」を押してください。';
const calonaviPlusFreeForever = '食事・運動・体重の記録は、無料でずっと使えます。';

String calonaviPlusGateTitle(String featureName) =>
    '$featureNameはカロナビ+の機能です';

String? calonaviPlusFeatureName(PlusFunnelFeature? feature) {
  return switch (feature) {
    PlusFunnelFeature.mealTemplateLimit => '食事テンプレート',
    PlusFunnelFeature.workoutTemplateLimit => '運動テンプレート',
    PlusFunnelFeature.widget => 'ウィジェット',
    PlusFunnelFeature.siri => '音声登録',
    PlusFunnelFeature.coach => 'パーソナルコーチ',
    PlusFunnelFeature.recentFoods => '直近3日の食品',
    PlusFunnelFeature.memo => 'メモ',
    PlusFunnelFeature.photoMeal => '写真で登録',
    PlusFunnelFeature.aiFoodLookup => 'AIで探す',
    null => null,
  };
}

String withCalonaviPlusFreeForever(String message) {
  if (message.contains(calonaviPlusFreeForever)) {
    return message;
  }
  return '$message\n$calonaviPlusFreeForever';
}

/// カロナビ+が無い機能を止める。Siri とウィジェットの判定は呼ばない。
///
/// 案内の表示と「カロナビ+を見る」は記録する。送信に失敗しても操作は止めない。
Future<bool> ensureCalonaviPlus(
  BuildContext context,
  AppController controller, {
  required String message,
  PlusFunnelFeature? feature,
  String? featureName,
}) async {
  if (controller.hasCalonaviPlusAccess) {
    return true;
  }
  await presentCalonaviPlusDialog(
    context,
    controller,
    message: message,
    feature: feature,
    featureName: featureName,
  );
  return controller.hasCalonaviPlusAccess;
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

/// 「カロナビ+限定機能」の確認。進むと購入画面（購入を復元あり）を開く。
Future<void> presentCalonaviPlusDialog(
  BuildContext context,
  AppController controller, {
  required String message,
  PlusFunnelFeature? feature,
  String? featureName,
  bool ignoreCurrentPlus = false,
}) async {
  if (!ignoreCurrentPlus && controller.hasCalonaviPlusAccess) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  controller.recordPlusFunnel(
    event: PlusFunnelEvent.gateShown,
    feature: feature,
  );
  final resolvedName = featureName ?? calonaviPlusFeatureName(feature);
  final openPlus = await showAppConfirmDialog(
    context: context,
    title: resolvedName == null
        ? AppStrings.plusGateTitle
        : calonaviPlusGateTitle(resolvedName),
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
