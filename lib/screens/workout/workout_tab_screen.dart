import 'package:flutter/material.dart';

import '../../models/exercise_entry.dart';
import '../../state/app_controller.dart';
import '../../utils/history_grouping.dart';
import '../../widgets/history/workout_history_list.dart';
import '../exercise/exercise_form_screen.dart';

class WorkoutTabScreen extends StatelessWidget {
  const WorkoutTabScreen({super.key, required this.controller});

  final AppController controller;

  Future<void> _confirmDeleteExercise(
    BuildContext context,
    ExerciseEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${entry.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      controller.deleteExercise(entry.id);
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
          appBar: AppBar(title: const Text('運動')),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openExerciseForm(context),
            child: const Icon(Icons.add),
          ),
          body: SafeArea(
            child: WorkoutHistoryList(
              dateGroups: displayGroups,
              onTapEntry: (entry) => _openExerciseForm(context, entry: entry),
              onDeleteEntry: (entry) => _confirmDeleteExercise(context, entry),
            ),
          ),
        );
      },
    );
  }
}
