import 'package:flutter/material.dart';

import '../../models/saved_food.dart';
import '../../state/app_controller.dart';
import '../../utils/nutrition_format.dart';
import '../../utils/saved_food_display_labels.dart';

class SavedFoodSuggestionList extends StatelessWidget {
  const SavedFoodSuggestionList({
    super.key,
    required this.controller,
    required this.foods,
    required this.onSelected,
  });

  final AppController controller;
  final List<SavedFood> foods;
  final ValueChanged<SavedFood> onSelected;

  @override
  Widget build(BuildContext context) {
    if (foods.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '保存済み食品',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ...foods
              .take(5)
              .map(
                (food) => ListTile(
                  dense: true,
                  title: Text(food.name),
                  subtitle: Text(
                    '${controller.formatSavedFoodBaseLabel(food)} · '
                    '${formatNullableNutrient(food.kcalPerBase)}kcal · '
                    'P${formatNullableNutrient(food.proteinPerBase)} '
                    'F${formatNullableNutrient(food.fatPerBase)} '
                    'C${formatNullableNutrient(food.carbPerBase)} · '
                    '${SavedFoodDisplayLabels.visibility(food.visibility)} · '
                    '${SavedFoodDisplayLabels.sourceType(food.sourceType)}',
                  ),
                  onTap: () => onSelected(food),
                ),
              ),
        ],
      ),
    );
  }
}
