import 'package:flutter/material.dart';

import '../../data/met_activity_catalog.dart';
import '../../models/alcohol_entry.dart';
import '../../models/exercise_entry.dart';
import '../../models/food_entry.dart';
import '../../models/weight_entry.dart';
import '../../services/health_exercise_credit.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/home_parts.dart';
import '../../utils/history_grouping.dart';
import '../../utils/kcal_display.dart';
import '../../utils/local_date.dart';
import '../../utils/record_clock.dart';
import '../../widgets/history/history_tab_body.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/common/delete_with_undo.dart';
import '../alcohol/alcohol_form_screen.dart';
import '../exercise/exercise_form_screen.dart';
import '../food/food_form_navigation.dart';
import '../weight/weight_record_screen.dart';

/// 指定日の食事・運動履歴。
class DayHistoryScreen extends StatelessWidget {
  const DayHistoryScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    required this.selectedDay,
    this.foodFormBuilder,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final DateTime selectedDay;
  final FoodFormScreenBuilder? foodFormBuilder;

  String _formatTime(DateTime time) {
    final local = civilClock(time);
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  DateTime get _initialLoggedAtForNewEntry =>
      initialLoggedAtForSelectedDay(selectedDay);

  bool get _canAdd => canAddRecordOnDay(selectedDay);

  Future<void> _confirmDeleteFood(BuildContext context, FoodEntry entry) async {
    await confirmDeleteWithUndo<FoodEntry>(
      context: context,
      title: '削除確認',
      message: '「${entry.name}」を削除しますか？',
      snapshot: entry,
      onDelete: () => controller.deleteFood(entry.id),
      onRestore: (restored) => controller.restoreFoodEntry(restored),
    );
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
      onDelete: () => controller.deleteExercise(entry.id),
      onRestore: (restored) => controller.restoreExerciseEntry(restored),
    );
  }

  Future<void> _confirmDeleteAlcohol(
    BuildContext context,
    AlcoholEntry entry,
  ) async {
    await confirmDeleteWithUndo<AlcoholEntry>(
      context: context,
      title: '削除確認',
      message: '「${entry.beverageName}」を削除しますか？',
      snapshot: entry,
      onDelete: () => controller.deleteAlcohol(entry.id),
      onRestore: (restored) => controller.restoreAlcoholEntry(restored),
    );
  }

  Future<void> _confirmDeleteWeight(
    BuildContext context,
    WeightEntry entry,
  ) async {
    await confirmDeleteWithUndo<WeightEntry>(
      context: context,
      title: '削除確認',
      message: 'この体重記録を削除しますか？',
      snapshot: entry,
      onDelete: () => controller.deleteWeightEntry(entry.id),
      onRestore: (restored) => controller.restoreWeightEntry(restored),
    );
  }

  void _openFoodForm(BuildContext context, {FoodEntry? entry}) {
    if (entry == null && !_canAdd) {
      showFutureDayAddBlockedSnackBar(context);
      return;
    }
    openFoodFormScreen(
      context,
      controller: controller,
      openFoodFactsService: openFoodFactsService,
      entry: entry,
      initialLoggedAt: entry == null ? _initialLoggedAtForNewEntry : null,
      foodFormBuilder: foodFormBuilder,
    );
  }

  void _openAlcoholForm(BuildContext context, {AlcoholEntry? entry}) {
    if (entry == null && !_canAdd) {
      showFutureDayAddBlockedSnackBar(context);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(
          name: 'day_history_screen_MaterialPageRoute_0',
        ),
        builder: (context) => AlcoholFormScreen(
          controller: controller,
          entry: entry,
          initialConsumedAt: entry == null ? _initialLoggedAtForNewEntry : null,
        ),
      ),
    );
  }

  void _openExerciseForm(BuildContext context, {ExerciseEntry? entry}) {
    if (entry == null && !_canAdd) {
      showFutureDayAddBlockedSnackBar(context);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(
          name: 'day_history_screen_MaterialPageRoute_1',
        ),
        builder: (context) => ExerciseFormScreen(
          controller: controller,
          entry: entry,
          initialLoggedAt: entry == null ? _initialLoggedAtForNewEntry : null,
        ),
      ),
    );
  }

  void _openWeightForm(BuildContext context, {WeightEntry? entry}) {
    if (entry == null && !_canAdd) {
      showFutureDayAddBlockedSnackBar(context);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(
          name: 'day_history_screen_MaterialPageRoute_2',
        ),
        builder: (context) => WeightRecordScreen(
          controller: controller,
          entry: entry,
          initialRecordedAt: entry == null ? _initialLoggedAtForNewEntry : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = localDayStart(civilClock(selectedDay));

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final foodItems = sortFoodEntriesByLoggedAt(
          controller.foodEntries
              .where((entry) => isLoggedOnLocalDay(entry.loggedAt, day))
              .toList(),
        );
        final exerciseItems =
            controller.exerciseEntries
                .where((entry) => isLoggedOnLocalDay(entry.loggedAt, day))
                .toList()
              ..sort((a, b) => compareRecordInstants(a.loggedAt, b.loggedAt));
        final alcoholItems =
            controller.alcoholEntries
                .where((entry) => isLoggedOnLocalDay(entry.consumedAt, day))
                .toList()
              ..sort(
                (a, b) => compareRecordInstants(a.consumedAt, b.consumedAt),
              );
        final weightItems =
            controller.weightEntries
                .where((entry) => isLoggedOnLocalDay(entry.recordedAt, day))
                .toList()
              ..sort(
                (a, b) => compareRecordInstants(a.recordedAt, b.recordedAt),
              );

        final daySummary = controller.summaryForDay(day);
        final intakeShown = displayedIntakeKcal(
          foods: foodItems,
          alcohol: alcoholItems,
        );
        final creditedExercise = const HealthExerciseCredit()
            .creditedManualExercises(
              healthActiveEnergyPresent: controller
                  .healthActiveEnergyPresentOn(day),
              dayExercises: exerciseItems,
              healthWorkouts: controller.healthWorkouts,
            );
        final burnShown = displayedBurnKcal(
          exercises: creditedExercise,
          healthExcessKcal:
              daySummary?.remainingBreakdown?.healthActivityExcessKcal ?? 0,
        );

        Widget section({
          required String icon,
          required String title,
          required String emptyMessage,
          required List<Widget> rows,
          VoidCallback? onAdd,
        }) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesignSectionHeader(
                icon: icon,
                title: title,
                actionLabel: onAdd != null ? '追加' : null,
                onAction: onAdd,
              ),
              const SizedBox(height: 4),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    emptyMessage,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyS.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                )
              else
                ...rows,
              const SizedBox(height: 16),
            ],
          );
        }

        return DesignPage(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesignTitleBlock(
                title: formatJapaneseDateWithWeekday(day),
                subtitle: 'この日の記録をまとめて見られます。長押しで削除できます。',
              ),
              DesignCard(
                elevated: false,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: StatItem(
                        label: '摂取',
                        value: intakeShown.toString(),
                      ),
                    ),
                    Expanded(
                      child: StatItem(
                        label: '消費',
                        value: '+$burnShown',
                      ),
                    ),
                    Expanded(
                      child: StatItem(
                        label: '差',
                        value: (intakeShown - burnShown).toString(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              section(
                icon: AppIcons.meal,
                title: '食事',
                emptyMessage: 'この日の食事記録はありません',
                onAdd: _canAdd ? () => _openFoodForm(context) : null,
                rows: [
                  for (final e in foodItems)
                    DesignListRow(
                      icon: AppIcons.meal,
                      time: _formatTime(e.loggedAt),
                      title: e.name,
                      value: formatNullableNutrient(
                        e.kcalPerUnit == null ? null : e.totalKcal,
                      ),
                      onTap: () => _openFoodForm(context, entry: e),
                      onLongPress: () => _confirmDeleteFood(context, e),
                    ),
                ],
              ),
              section(
                icon: AppIcons.alcohol,
                title: 'アルコール',
                emptyMessage: 'この日のアルコール記録はありません',
                onAdd: _canAdd ? () => _openAlcoholForm(context) : null,
                rows: [
                  for (final e in alcoholItems)
                    DesignListRow(
                      icon: AppIcons.alcohol,
                      time: _formatTime(e.consumedAt),
                      title: e.beverageName,
                      value: formatNullableNutrient(
                        e.totalCalories,
                        fractionDigits: 0,
                      ),
                      onTap: () => _openAlcoholForm(context, entry: e),
                      onLongPress: () => _confirmDeleteAlcohol(context, e),
                    ),
                ],
              ),
              section(
                icon: AppIcons.exercise,
                title: '運動',
                emptyMessage: 'この日の運動記録はありません',
                onAdd: _canAdd ? () => _openExerciseForm(context) : null,
                rows: [
                  for (final e in exerciseItems)
                    DesignListRow(
                      icon: AppIcons.exercise,
                      time: _formatTime(e.loggedAt),
                      title:
                          '${e.name}（${MetActivityCatalog.quantityLabelFor(e)}）',
                      value: displayedExerciseRow(
                        e.effectiveNetKcal,
                        overlapped: controller.exerciseRowOverlapsHealth(
                          e,
                          day,
                        ),
                      ),
                      onTap: () => _openExerciseForm(context, entry: e),
                      onLongPress: () => _confirmDeleteExercise(context, e),
                    ),
                ],
              ),
              section(
                icon: AppIcons.scale,
                title: '体重',
                emptyMessage: 'この日の体重記録はありません',
                onAdd: _canAdd ? () => _openWeightForm(context) : null,
                rows: [
                  for (final e in weightItems)
                    DesignListRow(
                      icon: AppIcons.scale,
                      time: _formatTime(e.recordedAt),
                      title: '体重',
                      value: e.weightKg.toStringAsFixed(1),
                      unit: 'kg',
                      onTap: () => _openWeightForm(context, entry: e),
                      onLongPress: () => _confirmDeleteWeight(context, e),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
