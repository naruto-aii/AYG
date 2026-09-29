import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// 食品保存時の公開範囲選択。
class SavedFoodVisibilitySelector extends StatelessWidget {
  const SavedFoodVisibilitySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final FoodVisibility value;
  final ValueChanged<FoodVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('公開範囲', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<FoodVisibility>(
          segments: const [
            ButtonSegment(
              value: FoodVisibility.private,
              label: Text('非公開'),
              icon: Icon(Icons.lock_outline),
            ),
            ButtonSegment(
              value: FoodVisibility.public,
              label: Text('公開'),
              icon: Icon(Icons.public),
            ),
          ],
          selected: {value},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value == FoodVisibility.private
              ? 'あなただけが利用できます。公開食品検索には表示されません。'
              : '他のユーザーも検索・利用できます。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
