import 'package:flutter/material.dart';

import '../../models/duplicate_saved_food_action.dart';
import '../../models/saved_food.dart';

/// 同名 private 保存済み食品が見つかった場合の選択ダイアログ。
Future<DuplicateSavedFoodDialogResult?> showDuplicateSavedFoodDialog({
  required BuildContext context,
  required SavedFood existingFood,
  required String enteredName,
}) async {
  return showDialog<DuplicateSavedFoodDialogResult>(
    context: context,
    builder: (context) => _DuplicateSavedFoodDialog(
      existingFood: existingFood,
      enteredName: enteredName,
    ),
  );
}

class DuplicateSavedFoodDialogResult {
  const DuplicateSavedFoodDialogResult({required this.action, this.newName});

  final DuplicateSavedFoodAction action;
  final String? newName;
}

class _DuplicateSavedFoodDialog extends StatefulWidget {
  const _DuplicateSavedFoodDialog({
    required this.existingFood,
    required this.enteredName,
  });

  final SavedFood existingFood;
  final String enteredName;

  @override
  State<_DuplicateSavedFoodDialog> createState() =>
      _DuplicateSavedFoodDialogState();
}

class _DuplicateSavedFoodDialogState extends State<_DuplicateSavedFoodDialog> {
  final _newNameController = TextEditingController();
  DuplicateSavedFoodAction? _selectedAction =
      DuplicateSavedFoodAction.useExisting;

  @override
  void dispose() {
    _newNameController.dispose();
    super.dispose();
  }

  void _submit() {
    final action = _selectedAction;
    if (action == null) {
      return;
    }
    if (action == DuplicateSavedFoodAction.saveAsNewName) {
      final newName = _newNameController.text.trim();
      if (newName.isEmpty) {
        return;
      }
      Navigator.of(
        context,
      ).pop(DuplicateSavedFoodDialogResult(action: action, newName: newName));
      return;
    }

    Navigator.of(context).pop(DuplicateSavedFoodDialogResult(action: action));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('同名の保存済み食品があります'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('「${widget.existingFood.name}」が既に登録されています。'),
            const SizedBox(height: 16),
            RadioListTile<DuplicateSavedFoodAction>(
              title: const Text('既存の食品を利用する'),
              subtitle: const Text('食事記録のみ保存し、新しい食品は作りません'),
              value: DuplicateSavedFoodAction.useExisting,
              groupValue: _selectedAction,
              onChanged: (value) => setState(() => _selectedAction = value),
            ),
            RadioListTile<DuplicateSavedFoodAction>(
              title: const Text('既存の食品を更新する'),
              subtitle: const Text('入力内容で既存食品を上書きします'),
              value: DuplicateSavedFoodAction.updateExisting,
              groupValue: _selectedAction,
              onChanged: (value) => setState(() => _selectedAction = value),
            ),
            RadioListTile<DuplicateSavedFoodAction>(
              title: const Text('別名で保存する'),
              value: DuplicateSavedFoodAction.saveAsNewName,
              groupValue: _selectedAction,
              onChanged: (value) => setState(() => _selectedAction = value),
            ),
            if (_selectedAction == DuplicateSavedFoodAction.saveAsNewName) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _newNameController,
                decoration: const InputDecoration(
                  labelText: '新しい食品名',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            RadioListTile<DuplicateSavedFoodAction>(
              title: const Text('食品として保存しない'),
              subtitle: const Text('食事記録のみ保存します'),
              value: DuplicateSavedFoodAction.skipSavedFood,
              groupValue: _selectedAction,
              onChanged: (value) => setState(() => _selectedAction = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(onPressed: _submit, child: const Text('続行')),
      ],
    );
  }
}
