import 'package:flutter/material.dart';

import '../../models/food_entry.dart';
import '../../theme/app_spacing.dart';
import '../../utils/history_grouping.dart';
import '../../utils/nutrition_format.dart';
import '../entry_list_tile.dart';
import 'history_section_widgets.dart';

typedef FoodEntryTap = void Function(FoodEntry entry);
typedef FoodEntryDelete = void Function(FoodEntry entry);

/// 日付 × 時間帯でグルーピングした食事履歴リスト。
class FoodHistoryList extends StatelessWidget {
  const FoodHistoryList({
    super.key,
    required this.dateGroups,
    required this.onTapEntry,
    required this.onDeleteEntry,
    this.emptyMessage = '記録された食事はありません',
  });

  final List<HistoryDateGroup<FoodEntry>> dateGroups;
  final FoodEntryTap onTapEntry;
  final FoodEntryDelete onDeleteEntry;
  final String emptyMessage;

  String _foodEntrySubtitle(FoodEntry entry) {
    final kcal = formatNullableNutrient(
      entry.kcalPerUnit == null ? null : entry.totalKcal,
    );
    final protein = formatNullableNutrient(
      entry.proteinPerUnit == null ? null : entry.totalProteinG,
    );
    final fat = formatNullableNutrient(
      entry.fatPerUnit == null ? null : entry.totalFatG,
    );
    final carb = formatNullableNutrient(
      entry.carbPerUnit == null ? null : entry.totalCarbG,
    );

    return '$kcal kcal / P $protein g / F $fat g / C $carb g / '
        '数量 ${entry.quantity.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    if (dateGroups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            emptyMessage,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (final dateGroup in dateGroups) ...[
          HistoryDateHeader(label: dateGroup.label),
          for (final mealGroup in groupFoodEntriesByMealSlot(
            dateGroup.items,
          )) ...[
            HistorySectionHeader(label: mealGroup.slot.label),
            if (mealGroup.entries.isEmpty)
              const HistoryEmptySlotMessage(message: '記録なし')
            else
              ...mealGroup.entries.map(
                (entry) => EntryListTile(
                  title: entry.name,
                  subtitle: _foodEntrySubtitle(entry),
                  leadingIcon: Icons.restaurant,
                  onTap: () => onTapEntry(entry),
                  onDelete: () => onDeleteEntry(entry),
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}
