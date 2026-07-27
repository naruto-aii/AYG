import 'package:flutter/material.dart';

import '../../state/app_controller.dart';

Future<bool> confirmBlockFoodCreator({
  required BuildContext context,
  required AppController controller,
  required String creatorUserId,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('作成者をブロック'),
      content: const Text(
        'この作成者をブロックします。\n'
        '今後、この作成者の公開食品は検索結果に表示されません。\n'
        '過去の食事記録は変更されません。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('ブロック'),
        ),
      ],
    ),
  );

  if (confirmed != true) {
    return false;
  }

  try {
    await controller.blockFoodCreator(creatorUserId);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('作成者をブロックしました')));
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ブロックに失敗しました: $error')));
    }
    return false;
  }
}

Future<bool> confirmUnblockFoodCreator({
  required BuildContext context,
  required AppController controller,
  required String creatorUserId,
}) async {
  try {
    await controller.unblockFoodCreator(creatorUserId);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ブロックを解除しました')));
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ブロック解除に失敗しました: $error')));
    }
    return false;
  }
}
