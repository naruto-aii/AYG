import 'package:flutter/material.dart';

import '../../models/exercise_entry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/history_grouping.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
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
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final List<HistoryDateGroup<ExerciseEntry>> dateGroups;
  final ExerciseEntryTap onTapEntry;
  final ExerciseEntryDelete onDeleteEntry;
  final String emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final hasEntries = dateGroups.any((group) => group.items.isNotEmpty);
    if (!hasEntries) {
      return AppEmptyState(
        message: emptyMessage,
        centered: true,
        actionLabel: emptyActionLabel,
        onAction: onEmptyAction,
      );
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
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xxs,
                      ),
                      onTap: () => onTapEntry(dateGroup.items[i]),
                      title: Text(dateGroup.items[i].name),
                      subtitle: Text(
                        '${_formatTime(dateGroup.items[i].loggedAt)} · '
                        '${dateGroup.items[i].durationMin} 分',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${dateGroup.items[i].burnedKcal.toStringAsFixed(0)} kcal',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppColors.accentOrange,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => onDeleteEntry(dateGroup.items[i]),
                            color: AppColors.secondaryText,
                          ),
                        ],
                      ),
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
