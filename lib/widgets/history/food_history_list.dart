import 'package:flutter/material.dart';

import '../../models/food_entry.dart';
import '../../constants/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/history_grouping.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/compact_macro_display.dart';
import 'history_section_widgets.dart';

typedef FoodEntryTap = void Function(FoodEntry entry);
typedef FoodEntryDelete = void Function(FoodEntry entry);

/// 日付でグルーピングした食事履歴リスト（画像なし）。
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

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _foodEntryQuantityLine(FoodEntry entry) {
    return '${AppStrings.quantityLabel} ${entry.quantity.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final hasEntries = dateGroups.any((group) => group.items.isNotEmpty);
    if (!hasEntries) {
      return AppEmptyState(message: emptyMessage, centered: true);
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        for (final dateGroup in dateGroups) ...[
          if (dateGroup.items.isNotEmpty) ...[
            HistoryDateHeader(label: dateGroup.label),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < dateGroup.items.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _FoodHistoryTile(
                      entry: dateGroup.items[i],
                      timeLabel: _formatTime(dateGroup.items[i].loggedAt),
                      quantityLine: _foodEntryQuantityLine(dateGroup.items[i]),
                      onTap: () => onTapEntry(dateGroup.items[i]),
                      onDelete: () => onDeleteEntry(dateGroup.items[i]),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ],
    );
  }
}

class _FoodHistoryTile extends StatelessWidget {
  const _FoodHistoryTile({
    required this.entry,
    required this.timeLabel,
    required this.quantityLine,
    required this.onTap,
    required this.onDelete,
  });

  final FoodEntry entry;
  final String timeLabel;
  final String quantityLine;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final kcal = formatNullableNutrient(
      entry.kcalPerUnit == null ? null : entry.totalKcal,
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      onTap: onTap,
      title: Text(entry.name),
      subtitle: VerticalMacroDisplay(
        leading: Text(timeLabel),
        kcal: entry.kcalPerUnit == null ? null : entry.totalKcal,
        proteinG: entry.proteinPerUnit == null ? null : entry.totalProteinG,
        fatG: entry.fatPerUnit == null ? null : entry.totalFatG,
        carbG: entry.carbPerUnit == null ? null : entry.totalCarbG,
        showKcal: false,
        trailing: Text(quantityLine),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$kcal kcal',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onDelete,
            color: AppColors.secondaryText,
          ),
        ],
      ),
    );
  }
}
