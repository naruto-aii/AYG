import 'package:flutter/material.dart';

import '../../models/exercise_entry.dart';
import '../../theme/app_spacing.dart';
import '../../utils/history_grouping.dart';
import '../entry_list_tile.dart';
import 'history_section_widgets.dart';

typedef ExerciseEntryTap = void Function(ExerciseEntry entry);
typedef ExerciseEntryDelete = void Function(ExerciseEntry entry);

/// 日付単位でグルーピングした運動履歴リスト。
class WorkoutHistoryList extends StatelessWidget {
  const WorkoutHistoryList({
    super.key,
    required this.dateGroups,
    required this.onTapEntry,
    required this.onDeleteEntry,
    this.emptyMessage = '記録された運動はありません',
  });

  final List<HistoryDateGroup<ExerciseEntry>> dateGroups;
  final ExerciseEntryTap onTapEntry;
  final ExerciseEntryDelete onDeleteEntry;
  final String emptyMessage;

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
          if (dateGroup.items.isEmpty)
            const HistoryEmptySlotMessage(message: '記録なし')
          else
            ...dateGroup.items.map(
              (entry) => EntryListTile(
                title: entry.name,
                subtitle:
                    '${entry.burnedKcal.toStringAsFixed(0)} kcal / '
                    '${entry.durationMin} 分',
                leadingIcon: Icons.fitness_center,
                onTap: () => onTapEntry(entry),
                onDelete: () => onDeleteEntry(entry),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}
