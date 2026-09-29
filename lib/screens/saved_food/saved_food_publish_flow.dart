import 'package:flutter/material.dart';

import '../../models/saved_food.dart';
import '../../state/app_controller.dart';
import '../../widgets/saved_food/public_food_duplicate_dialog.dart';
import '../../widgets/saved_food/public_food_similar_dialog.dart';
import 'publish_saved_food_confirmation_screen.dart';

/// private 食品の公開フローを開始する。
Future<bool> startSavedFoodPublishFlow({
  required BuildContext context,
  required AppController controller,
  required SavedFood food,
}) async {
  final validation = controller.validateSavedFoodForPublish(food);
  if (!validation.isValid) {
    await _showMessage(context, validation.errors.join('\n'));
    return false;
  }

  final duplicate = await controller.checkPublicDuplicate(food);
  if (duplicate != null && context.mounted) {
    final action = await showPublicFoodDuplicateDialog(
      context: context,
      controller: controller,
      duplicate: duplicate,
    );
    return switch (action) {
      PublicFoodDuplicateAction.useExisting ||
      PublicFoodDuplicateAction.keepPrivate ||
      PublicFoodDuplicateAction.editInput ||
      PublicFoodDuplicateAction.cancel ||
      null => false,
    };
  }

  final similarFoods = await controller.findSimilarPublicFoods(food);
  if (similarFoods.isNotEmpty && context.mounted) {
    final action = await showPublicFoodSimilarDialog(
      context: context,
      controller: controller,
      similarFoods: similarFoods,
    );
    if (action != PublicFoodSimilarAction.continuePublish) {
      return false;
    }
  }

  if (!context.mounted) {
    return false;
  }

  final result = await Navigator.of(context).push<PublishConfirmationAction>(
    MaterialPageRoute(
      builder: (context) => PublishSavedFoodConfirmationScreen(
        controller: controller,
        food: food,
        duplicate: duplicate,
        similarFoods: similarFoods,
        validationErrors: validation.errors,
        manualMacroConsistent: validation.manualMacroConsistent,
      ),
    ),
  );

  return result == PublishConfirmationAction.publish;
}

Future<void> confirmUnpublishSavedFood({
  required BuildContext context,
  required AppController controller,
  required SavedFood food,
  required VoidCallback onSuccess,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('非公開にしますか？'),
      content: const Text(
        'この食品を非公開にします。\n'
        '今後、他のユーザーは検索・新規利用できなくなります。\n'
        'すでに記録済みの食事やテンプレートのスナップショットは変更されません。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('非公開にする'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  try {
    await controller.unpublishSavedFood(food.foodId);
    onSuccess();
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    await _showMessage(context, controller.publishErrorMessage(error));
  }
}

Future<void> _showMessage(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
