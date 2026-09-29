import 'package:flutter/material.dart';

import '../../models/exercise_entry.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../utils/history_grouping.dart';
import '../../utils/local_date.dart';
import '../../widgets/common/delete_with_undo.dart';
import '../../widgets/history/history_tab_body.dart';
import '../../widgets/history/workout_history_list.dart';
import '../../widgets/layout/app_content_constraint.dart';
import '../exercise/exercise_form_screen.dart';
import '../food/food_form_navigation.dart';
import '../history/history_calendar_screen.dart';
import '../workout_template/workout_template_screens.dart';

class WorkoutTabScreen extends StatefulWidget {
  const WorkoutTabScreen({
    super.key,
    required this.controller,
    this.openFoodFactsService,
    this.foodFormBuilder,
  });

  final AppController controller;
  final OpenFoodFactsService? openFoodFactsService;
  final FoodFormScreenBuilder? foodFormBuilder;

  @override
  State<WorkoutTabScreen> createState() => _WorkoutTabScreenState();
}

class _WorkoutTabScreenState extends State<WorkoutTabScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = localDayStart(DateTime.now());
  }

  Future<void> _confirmDeleteExercise(
    BuildContext context,
    ExerciseEntry entry,
  ) async {
    await confirmDeleteWithUndo<ExerciseEntry>(
      context: context,
      title: '削除確認',
      message: '「${entry.name}」を削除しますか？',
      snapshot: entry,
      onDelete: () => widget.controller.deleteExercise(entry.id),
      onRestore: (restored) => widget.controller.restoreExerciseEntry(restored),
    );
  }

  void _openExerciseForm(BuildContext context, {ExerciseEntry? entry}) {
    if (entry == null && !canAddRecordOnDay(_selectedDate)) {
      showFutureDayAddBlockedSnackBar(context);
      return;
    }

    final initialLoggedAt = entry == null ? _initialLoggedAtForNewEntry : null;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ExerciseFormScreen(
          controller: widget.controller,
          entry: entry,
          initialLoggedAt: initialLoggedAt,
        ),
      ),
    );
  }

  DateTime get _initialLoggedAtForNewEntry =>
      initialLoggedAtForSelectedDay(_selectedDate);

  void _openHistoryCalendar() {
    final openFoodFactsService = widget.openFoodFactsService;
    if (openFoodFactsService == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => HistoryCalendarScreen(
          controller: widget.controller,
          openFoodFactsService: openFoodFactsService,
          foodFormBuilder: widget.foodFormBuilder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final dateGroups = groupExerciseEntriesByDate(
          widget.controller.exerciseEntries,
          referenceDate: _selectedDate,
          todayOnly: true,
        );
        final displayGroups = dateGroups.isEmpty
            ? [
                HistoryDateGroup<ExerciseEntry>(
                  date: _selectedDate,
                  label: dateLabelFor(
                    _selectedDate,
                    referenceDate: DateTime.now(),
                  ),
                  items: const [],
                ),
              ]
            : dateGroups;

        return Scaffold(
          appBar: AppBar(
            title: const Text('運動'),
            actions: [
              if (widget.openFoodFactsService != null)
                Semantics(
                  label: '履歴カレンダー',
                  button: true,
                  child: IconButton(
                    onPressed: _openHistoryCalendar,
                    icon: const Icon(Icons.calendar_month_outlined),
                  ),
                ),
              Semantics(
                label: '運動テンプレート',
                button: true,
                child: IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => WorkoutTemplateListScreen(
                          controller: widget.controller,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.list_alt_outlined),
                ),
              ),
              Semantics(
                label: '運動追加',
                button: true,
                child: IconButton(
                  onPressed: () => _openExerciseForm(context),
                  icon: const Icon(Icons.add),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: AppContentConstraint(
              expandVertically: true,
              child: HistoryTabBody(
                selectedDate: _selectedDate,
                onSelectedDateChanged: (date) {
                  setState(() => _selectedDate = date);
                },
                onOpenCalendar: widget.openFoodFactsService == null
                    ? null
                    : _openHistoryCalendar,
                listChild: WorkoutHistoryList(
                  dateGroups: displayGroups,
                  onTapEntry: (entry) =>
                      _openExerciseForm(context, entry: entry),
                  onDeleteEntry: (entry) =>
                      _confirmDeleteExercise(context, entry),
                  emptyMessage: 'この日の運動記録はありません',
                  emptyActionLabel: canAddRecordOnDay(_selectedDate)
                      ? '運動を追加'
                      : null,
                  onEmptyAction: canAddRecordOnDay(_selectedDate)
                      ? () => _openExerciseForm(context)
                      : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
