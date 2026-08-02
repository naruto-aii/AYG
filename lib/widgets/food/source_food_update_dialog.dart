import 'package:flutter/material.dart';

import '../../services/source_food_edit_policy.dart';

/// 履歴編集時の登録元保存食品更新確認ダイアログ。
Future<SourceFoodUpdateChoice?> showSourceFoodUpdateDialog({
  required BuildContext context,
  required bool isOwnSavedFood,
}) {
  return showDialog<SourceFoodUpdateChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('登録元の食品も変更しますか？'),
      content: Text(
        isOwnSavedFood
            ? '1単位当たりの成分や商品情報を変更しました。'
                  '今回の記録だけ更新するか、保存済み食品（登録元）も一緒に更新できます。'
            : '他ユーザーの公開食品を元にしています。'
                  '登録元を直接変更できないため、今回の記録だけ更新するか、'
                  '自分の保存食品としてコピーして更新できます。',
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(SourceFoodUpdateChoice.cancel),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(SourceFoodUpdateChoice.entryOnly),
          child: const Text('今回の記録だけ変更'),
        ),
        if (isOwnSavedFood)
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(SourceFoodUpdateChoice.updateSource),
            child: const Text('登録元の食品も更新'),
          )
        else
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(SourceFoodUpdateChoice.copyAndUpdateSource),
            child: const Text('自分の食品としてコピーして更新'),
          ),
      ],
    ),
  );
}
