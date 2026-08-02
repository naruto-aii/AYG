import 'package:flutter/material.dart';

import '../../models/saved_food.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../constants/app_strings.dart';
import '../../utils/macro_display.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/common/compact_macro_display.dart';
import '../../utils/saved_food_display_labels.dart';
import '../common/app_card.dart';
import '../common/app_section_header.dart';

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

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xxs,
              ),
              child: AppSectionHeader(title: '保存済み食品'),
            ),
            ...foods
                .take(5)
                .map(
                  (food) => ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    title: Text(food.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(controller.formatSavedFoodBaseLabel(food)),
                        CompactMacroDisplay(
                          kcal: food.kcalPerBase,
                          proteinG: food.proteinPerBase,
                          fatG: food.fatPerBase,
                          carbG: food.carbPerBase,
                        ),
                        Text(
                          '${SavedFoodDisplayLabels.visibility(food.visibility)} · '
                          '${SavedFoodDisplayLabels.sourceType(food.sourceType)}',
                        ),
                      ],
                    ),
                    onTap: () => onSelected(food),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
