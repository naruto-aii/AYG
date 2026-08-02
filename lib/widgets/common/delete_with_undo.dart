import 'package:flutter/material.dart';

import 'app_confirm_dialog.dart';

/// 削除確認後、Snackbar で元に戻せる削除フロー。
Future<void> confirmDeleteWithUndo<T>({
  required BuildContext context,
  required String title,
  required String message,
  required T snapshot,
  required Future<void> Function() onDelete,
  required Future<void> Function(T snapshot) onRestore,
  String undoLabel = '元に戻す',
  String deletedMessage = '削除しました',
}) async {
  final confirmed = await showAppConfirmDialog(
    context: context,
    title: title,
    message: message,
  );
  if (confirmed != true) {
    return;
  }

  await onDelete();
  if (!context.mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(deletedMessage),
      action: SnackBarAction(
        label: undoLabel,
        onPressed: () {
          onRestore(snapshot);
        },
      ),
    ),
  );
}

/// 未来日への新規記録追加を制限する。
bool canAddRecordOnDay(DateTime selectedDay) {
  final today = DateTime.now();
  final day = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
  final todayStart = DateTime(today.year, today.month, today.day);
  return !day.isAfter(todayStart);
}

void showFutureDayAddBlockedSnackBar(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('未来の日付には記録を追加できません')));
}
