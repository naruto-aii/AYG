import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import 'calonavi_plus_flow.dart';

/// カロナビ+が無い機能を止める。Siri とウィジェットの判定は呼ばない。
Future<bool> ensureCalonaviPlus(
  BuildContext context,
  AppController controller, {
  required String message,
}) async {
  if (controller.subscriptionRepository.isPlusActive) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  final openPlus = await showAppConfirmDialog(
    context: context,
    title: 'こちらは有料の機能です',
    message: message,
    confirmLabel: 'カロナビ+を見る',
    cancelLabel: '閉じる',
  );
  if (openPlus == true && context.mounted) {
    final custom = controller.openCalonaviPlusFlow;
    if (custom != null) {
      await custom(context);
    } else {
      await showCalonaviPlus(
        context,
        repository: controller.subscriptionRepository,
      );
    }
  }
  return controller.subscriptionRepository.isPlusActive;
}
