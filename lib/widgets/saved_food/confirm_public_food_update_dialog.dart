import 'package:flutter/material.dart';

/// 公開食品を更新する前に表示する確認 Popup。
Future<bool> showConfirmPublicFoodUpdateDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('公開食品を更新'),
      content: const Text(
        '公開食品を更新します。\n'
        'すでに記録済みの食事内容は変更されません。\n'
        '今後この食品を利用するユーザーには新しい内容が表示されます。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('更新する'),
        ),
      ],
    ),
  );
  return result ?? false;
}
