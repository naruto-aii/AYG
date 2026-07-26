import 'package:flutter/material.dart';

import '../../models/public_food_publish_match.dart';
import '../../state/app_controller.dart';
import 'public_food_match_card.dart';

enum PublicFoodSimilarAction { continuePublish, useExisting, editInput, cancel }

Future<PublicFoodSimilarAction?> showPublicFoodSimilarDialog({
  required BuildContext context,
  required AppController controller,
  required List<PublicFoodSimilarMatch> similarFoods,
}) {
  return showDialog<PublicFoodSimilarAction>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('類似する公開食品があります'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('類似食品を確認してください。登録を続けることもできます。'),
            const SizedBox(height: 12),
            ...similarFoods.map(
              (match) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PublicFoodMatchCard.fromSimilar(
                  controller: controller,
                  match: match,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(PublicFoodSimilarAction.cancel),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(PublicFoodSimilarAction.editInput),
          child: const Text('入力内容を修正する'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(PublicFoodSimilarAction.useExisting),
          child: const Text('既存食品を利用する'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(PublicFoodSimilarAction.continuePublish),
          child: const Text('登録を続ける'),
        ),
      ],
    ),
  );
}
