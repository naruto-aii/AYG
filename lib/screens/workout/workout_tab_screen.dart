import 'package:flutter/material.dart';

import '../../models/exercise_entry.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/history_grouping.dart';
import '../../utils/local_date.dart';
import '../../widgets/history/history_tab_body.dart';
import '../../widgets/common/delete_with_undo.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_icon.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/layout/active_tab_listenable_builder.dart';
import '../../widgets/design/home_parts.dart';
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
  static const _horizontal = EdgeInsets.symmetric(
    horizontal: AppSpacing.screenHorizontal,
  );
  static const _bottom = EdgeInsets.fromLTRB(
    AppSpacing.screenHorizontal,
    6,
    AppSpacing.screenHorizontal,
    6,
  );

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
      settings: const RouteSettings(name: 'workout_tab_screen_MaterialPageRoute_0'),
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
      settings: const RouteSettings(name: 'workout_tab_screen_MaterialPageRoute_1'),
        builder: (context) => HistoryCalendarScreen(
          controller: widget.controller,
          openFoodFactsService: openFoodFactsService,
          foodFormBuilder: widget.foodFormBuilder,
        ),
      ),
    );
  }

  void _openTemplates() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'workout_tab_screen_MaterialPageRoute_2'),
        builder: (context) =>
            WorkoutTemplateListScreen(controller: widget.controller),
      ),
    );
  }

  void _shiftDay(int delta) {
    setState(() {
      _selectedDate = localDayStart(
        DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day + delta,
        ),
      );
    });
  }

  String get _dayLabel {
    final d = _selectedDate;
    final base =
        '${d.month}月${d.day}日（${japaneseWeekdayLabels[d.weekday - 1]}）';
    return isSameLocalDay(d, DateTime.now()) ? '今日 $base' : base;
  }

  static String _time(DateTime time) =>
      '${time.hour}:${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ActiveTabListenableBuilder(
      listenable: widget.controller,
      builder: (context) {
        final groups = groupExerciseEntriesByDate(
          widget.controller.exerciseEntries,
          referenceDate: _selectedDate,
          todayOnly: true,
        );
        final entries = groups.isEmpty
            ? const <ExerciseEntry>[]
            : groups.first.items;
        final isToday = isSameLocalDay(_selectedDate, DateTime.now());
        final canAdd = canAddRecordOnDay(_selectedDate);
        final dayWord = isToday ? '今日' : 'この日';

        return DesignPage(
          bodyPadding: _horizontal,
          bottomBarPadding: _bottom,
          bottomBar: DesignButton(
            label: '運動を追加',
            onPressed: canAdd ? () => _openExerciseForm(context) : null,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesignTitleBlock(
                title: '運動',
                showBack: false,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '運動テンプレート',
                      onPressed: _openTemplates,
                      icon: const AppIcon(
                        AppIcons.template,
                        size: 24,
                        color: AppColors.iconPrimary,
                      ),
                    ),
                    if (widget.openFoodFactsService != null)
                      IconButton(
                        tooltip: '履歴カレンダー',
                        onPressed: _openHistoryCalendar,
                        icon: const AppIcon(
                          AppIcons.calendar,
                          size: 24,
                          color: AppColors.iconPrimary,
                        ),
                      ),
                  ],
                ),
              ),
              DesignCard(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '前の日',
                      onPressed: () => _shiftDay(-1),
                      icon: const DesignIcon(
                        Symbols.chevron_left_rounded,
                        size: 20,
                        color: AppColors.iconMuted,
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: widget.openFoodFactsService == null
                            ? null
                            : _openHistoryCalendar,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            _dayLabel,
                            textAlign: TextAlign.center,
                            style: AppTypography.titleM,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '次の日',
                      onPressed: isToday ? null : () => _shiftDay(1),
                      icon: DesignIcon(
                        Symbols.chevron_right_rounded,
                        size: 20,
                        color: isToday
                            ? AppColors.neutral300
                            : AppColors.iconMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DesignSectionHeader(
                icon: AppIcons.exercise,
                title: '$dayWordの運動',
              ),
              const SizedBox(height: AppSpacing.md),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    'この日の運動記録はありません',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyS.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                )
              else
                for (final entry in entries)
                  DesignListRow(
                    icon: AppIcons.exercise,
                    time: _time(entry.loggedAt),
                    title: entry.name,
                    value: entry.effectiveNetKcal.toStringAsFixed(0),
                    onTap: () => _openExerciseForm(context, entry: entry),
                    onLongPress: () => _confirmDeleteExercise(context, entry),
                  ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '記録は長押しで削除できます。',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }
}
