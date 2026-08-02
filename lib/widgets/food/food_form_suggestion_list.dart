import 'package:flutter/material.dart';

import '../../models/food_form_suggestion.dart';
import '../../models/meal_template.dart';
import '../../models/saved_food.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_section_header.dart';
import '../../widgets/common/compact_macro_display.dart';
import '../../utils/saved_food_display_labels.dart';

/// 食事登録フォームの候補（保存済み食品 / 食事テンプレート）。
class FoodFormSuggestionList extends StatelessWidget {
  const FoodFormSuggestionList({
    super.key,
    this.controller,
    required this.suggestions,
    required this.onSavedFoodSelected,
    required this.onMealTemplateSelected,
    this.formatSavedFoodBaseLabel,
  }) : assert(
         controller != null || formatSavedFoodBaseLabel != null,
         'controller or formatSavedFoodBaseLabel is required',
       );

  final AppController? controller;
  final List<FoodFormSuggestion> suggestions;
  final ValueChanged<SavedFood> onSavedFoodSelected;
  final ValueChanged<MealTemplate> onMealTemplateSelected;
  final String Function(SavedFood food)? formatSavedFoodBaseLabel;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    final savedFoods = suggestions
        .whereType<SavedFoodFormSuggestion>()
        .toList();
    final templates = suggestions
        .whereType<MealTemplateFormSuggestion>()
        .toList();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (savedFoods.isNotEmpty)
            _SavedFoodSection(
              controller: controller,
              suggestions: savedFoods,
              onSelected: onSavedFoodSelected,
              formatSavedFoodBaseLabel: formatSavedFoodBaseLabel,
            ),
          if (savedFoods.isNotEmpty && templates.isNotEmpty)
            const SizedBox(height: AppSpacing.sm),
          if (templates.isNotEmpty)
            _MealTemplateSection(
              suggestions: templates,
              onSelected: onMealTemplateSelected,
            ),
        ],
      ),
    );
  }
}

class _SavedFoodSection extends StatelessWidget {
  const _SavedFoodSection({
    required this.controller,
    required this.suggestions,
    required this.onSelected,
    this.formatSavedFoodBaseLabel,
  });

  final AppController? controller;
  final List<SavedFoodFormSuggestion> suggestions;
  final ValueChanged<SavedFood> onSelected;
  final String Function(SavedFood food)? formatSavedFoodBaseLabel;

  String _formatBase(SavedFood food) =>
      formatSavedFoodBaseLabel?.call(food) ??
      controller!.formatSavedFoodBaseLabel(food);

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
          ...suggestions
              .take(5)
              .map(
                (suggestion) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.restaurant_outlined, size: 20),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  title: Text(suggestion.food.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_formatBase(suggestion.food)} · '
                        '利用 ${suggestion.food.useCount} 回',
                      ),
                      CompactMacroDisplay(
                        kcal: suggestion.food.kcalPerBase,
                        proteinG: suggestion.food.proteinPerBase,
                        fatG: suggestion.food.fatPerBase,
                        carbG: suggestion.food.carbPerBase,
                      ),
                      Text(
                        SavedFoodDisplayLabels.visibility(
                          suggestion.food.visibility,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => onSelected(suggestion.food),
                ),
              ),
        ],
      ),
    );
  }
}

class _MealTemplateSection extends StatelessWidget {
  const _MealTemplateSection({
    required this.suggestions,
    required this.onSelected,
  });

  final List<MealTemplateFormSuggestion> suggestions;
  final ValueChanged<MealTemplate> onSelected;

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
            child: AppSectionHeader(title: '食事テンプレート'),
          ),
          ...suggestions
              .take(5)
              .map(
                (suggestion) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.library_books_outlined, size: 20),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  title: Text(suggestion.template.name),
                  subtitle: Text(
                    '${suggestion.itemCount}品 · '
                    '${formatNullableNutrient(suggestion.template.totalKcal)}kcal · '
                    '利用 ${suggestion.template.useCount} 回',
                  ),
                  onTap: () => onSelected(suggestion.template),
                ),
              ),
        ],
      ),
    );
  }
}
