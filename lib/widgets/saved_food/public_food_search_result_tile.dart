import 'package:flutter/material.dart';

import '../../models/public_food_search_match.dart';
import '../../state/app_controller.dart';
import '../../utils/nutrition_format.dart';
import '../../utils/saved_food_display_labels.dart';

class PublicFoodSearchResultTile extends StatelessWidget {
  const PublicFoodSearchResultTile({
    super.key,
    required this.controller,
    required this.match,
    required this.onTap,
  });

  final AppController controller;
  final PublicFoodSearchMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final food = match.food;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(food.name, style: theme.textTheme.titleMedium),
                  ),
                  Chip(
                    label: const Text('ユーザー登録食品'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${controller.formatSavedFoodBaseLabel(food)} · '
                '${formatNullableNutrient(food.kcalPerBase)}kcal · '
                'P${formatNullableNutrient(food.proteinPerBase)} '
                'F${formatNullableNutrient(food.fatPerBase)} '
                'C${formatNullableNutrient(food.carbPerBase)}',
              ),
              if (food.brand != null && food.brand!.isNotEmpty)
                Text('ブランド: ${food.brand}'),
              Text(
                '登録元: ${SavedFoodDisplayLabels.sourceType(food.sourceType)} · '
                'Good ${match.goodCount} / Bad ${match.badCount}',
              ),
              Text('更新: ${_formatDateTime(food.updatedAt)} · v${food.version}'),
              if (match.hasLowRating) ...[
                const SizedBox(height: 8),
                Text(
                  '低い評価が多い食品です。基準量と栄養情報を確認してから利用してください。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
