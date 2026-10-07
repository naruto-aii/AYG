import 'package:flutter/material.dart';

import '../../state/app_controller.dart';

/// メモの入力。キャンセルは null。空欄は空文字。
Future<String?> askFoodMemo(
  BuildContext context, {
  String? initial,
  String title = 'メモ',
}) {
  final editor = TextEditingController(text: initial ?? '');
  return showDialog<String>(
      routeSettings: const RouteSettings(name: 'food_memo_dialog_showDialog_0'),
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: editor,
        autofocus: true,
        maxLength: AppController.foodMemoMaxLength,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: '少し多かったから明日は150',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(editor.text),
          child: const Text('保存'),
        ),
      ],
    ),
  ).whenComplete(editor.dispose);
}
