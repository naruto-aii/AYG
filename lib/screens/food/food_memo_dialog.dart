import 'package:flutter/material.dart';

import '../../state/app_controller.dart';

/// メモの入力。キャンセルは null。空欄は空文字。
Future<String?> askFoodMemo(
  BuildContext context, {
  String? initial,
  String title = 'メモ',
}) {
  return showDialog<String>(
    routeSettings: const RouteSettings(name: 'food_memo_dialog_showDialog_0'),
    context: context,
    builder: (context) => _FoodMemoDialog(initial: initial, title: title),
  );
}

class _FoodMemoDialog extends StatefulWidget {
  const _FoodMemoDialog({required this.title, this.initial});

  final String title;
  final String? initial;

  @override
  State<_FoodMemoDialog> createState() => _FoodMemoDialogState();
}

class _FoodMemoDialogState extends State<_FoodMemoDialog> {
  late final TextEditingController _editor = TextEditingController(
    text: widget.initial ?? '',
  );

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _editor,
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
          onPressed: () => Navigator.of(context).pop(_editor.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
