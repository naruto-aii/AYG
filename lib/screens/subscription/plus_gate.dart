import 'package:flutter/material.dart';

import '../../repositories/plus_funnel_repository.dart';
import '../../services/analytics/analytics.dart';
import '../../state/app_controller.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import 'calonavi_plus_flow.dart';

const calonaviPlusFreeForever = '食事・運動・体重の記録は、無料でずっと使えます。';

String calonaviPlusGateTitle(String featureName) =>
    '$featureNameはカロナビ+の機能です';

String? calonaviPlusFeatureName(PlusFunnelFeature? feature) {
  return switch (feature) {
    PlusFunnelFeature.mealTemplateLimit => '食事テンプレート',
    PlusFunnelFeature.workoutTemplateLimit => '運動テンプレート',
    PlusFunnelFeature.widget => 'ウィジェット',
    PlusFunnelFeature.siri => '音声登録',
    PlusFunnelFeature.coach => '食事の提案',
    PlusFunnelFeature.recentFoods => '直近3日の食品',
    PlusFunnelFeature.memo => 'メモ',
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
  if (!context.mounted) {
    return false;
  }
  controller.recordPlusFunnel(
    event: PlusFunnelEvent.gateShown,
    feature: feature,
  );
  final resolvedName = featureName ?? calonaviPlusFeatureName(feature);
  final openPlus = await showAppConfirmDialog(
    context: context,
    title: resolvedName == null
        ? 'こちらは有料の機能です'
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
  return controller.hasCalonaviPlusAccess;
}
