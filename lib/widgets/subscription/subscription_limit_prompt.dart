import 'package:flutter/material.dart';

import '../../repositories/subscription_exceptions.dart';
import '../../screens/subscription/calonavi_plus_flow.dart';
import '../../state/app_controller.dart';
import '../common/app_confirm_dialog.dart';

/// 無料枠の上限に当たったときの案内。確認するとカロナビ+を開く。
///
/// 設定の「ウィジェット」「音声登録」と同じ、確認ダイアログ→カロナビ+の形。
Future<void> showSubscriptionLimitPrompt(
  BuildContext context, {
  required AppController controller,
  required SubscriptionLimitExceededException exception,
}) async {
  final openPlus = await showAppConfirmDialog(
    context: context,
    title: 'こちらは有料の機能です',
    message: exception.toString(),
    confirmLabel: 'カロナビ+を見る',
    cancelLabel: '閉じる',
  );
  if (openPlus != true || !context.mounted) {
    return;
  }
  final custom = controller.openCalonaviPlusFlow;
  if (custom != null) {
    await custom(context);
    return;
  }
  await showCalonaviPlus(context, repository: controller.subscriptionRepository);
}
