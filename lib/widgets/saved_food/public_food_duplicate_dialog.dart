import 'package:flutter/material.dart';

import '../../models/public_food_publish_match.dart';
import '../../state/app_controller.dart';
import 'public_food_match_card.dart';

enum PublicFoodDuplicateAction { useExisting, keepPrivate, editInput, cancel }

Future<PublicFoodDuplicateAction?> showPublicFoodDuplicateDialog({
  required BuildContext context,
  required AppController controller,
  required PublicFoodPublishMatch duplicate,
}) {
  return showDialog<PublicFoodDuplicateAction>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('同じ公開食品があります'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('同じ食品名・基準量・単位の公開食品がすでに存在するため、公開できません。'),
            const SizedBox(height: 12),
            PublicFoodMatchCard.fromMatch(
              controller: controller,
              match: duplicate,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(PublicFoodDuplicateAction.cancel),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(PublicFoodDuplicateAction.editInput),
          child: const Text('入力内容を修正する'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(PublicFoodDuplicateAction.keepPrivate),
          child: const Text('privateのまま保存'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(PublicFoodDuplicateAction.useExisting),
          child: const Text('既存食品を利用する'),
        ),
      ],
    ),
  );
}
