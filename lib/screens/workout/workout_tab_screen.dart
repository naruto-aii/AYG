import 'package:flutter/material.dart';

import '../../models/exercise_entry.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../utils/history_grouping.dart';
import '../../widgets/brand/app_logo.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../widgets/history/workout_history_list.dart';
import '../exercise/exercise_form_screen.dart';

class WorkoutTabScreen extends StatelessWidget {
  const WorkoutTabScreen({super.key, required this.controller});

  final AppController controller;

  Future<void> _confirmDeleteExercise(
    BuildContext context,
    ExerciseEntry entry,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '削除確認',
      message: '「${entry.name}」を削除しますか？',
    );

    if (confirmed == true) {
      await controller.deleteExercise(entry.id);
    }
  }

  void _openExerciseForm(BuildContext context, {ExerciseEntry? entry}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            ExerciseFormScreen(controller: controller, entry: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final dateGroups = groupExerciseEntriesByDate(
          controller.exerciseEntries,
          referenceDate: DateTime.now(),
        );
        final displayGroups = dateGroups.isEmpty
            ? [
                HistoryDateGroup<ExerciseEntry>(
                  date: DateTime.now(),
                  label: '今日',
                  items: const [],
                ),
              ]
            : dateGroups;

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openExerciseForm(context),
            icon: const Icon(Icons.add),
            label: const Text('運動追加'),
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.screenPadding,
                    AppSpacing.screenPadding,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppLogo(height: 28),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '運動',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: WorkoutHistoryList(
                    dateGroups: displayGroups,
                    onTapEntry: (entry) =>
                        _openExerciseForm(context, entry: entry),
                    onDeleteEntry: (entry) =>
                        _confirmDeleteExercise(context, entry),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
