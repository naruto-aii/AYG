import 'package:flutter/material.dart';

import '../../models/alcohol_entry.dart';
import '../../models/exercise_entry.dart';
import '../../models/food_entry.dart';
import '../../models/weight_entry.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../constants/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/history_grouping.dart';
import '../../utils/local_date.dart';
import '../../widgets/history/history_tab_body.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/delete_with_undo.dart';
import '../../widgets/common/compact_macro_display.dart';
import '../../widgets/layout/app_content_constraint.dart';
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

  String get _title {
    final day = selectedDay.toLocal();
    return '${day.year}/${day.month}/${day.day}';
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
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
        builder: (context) => WeightRecordScreen(
          controller: controller,
          entry: entry,
          initialRecordedAt: entry == null ? _initialLoggedAtForNewEntry : null,
        ),
      ),
    );
  }

  String _foodEntryQuantityLine(FoodEntry entry) {
    return '${AppStrings.quantityLabel} ${entry.quantity.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final day = localDayStart(selectedDay.toLocal());

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final foodItems = sortFoodEntriesByLoggedAt(
          controller.foodEntries
              .where((entry) => isSameLocalDay(entry.loggedAt, day))
              .toList(),
        );
        final exerciseItems =
            controller.exerciseEntries
                .where((entry) => isSameLocalDay(entry.loggedAt, day))
                .toList()
              ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
        final alcoholItems =
            controller.alcoholEntries
                .where((entry) => isSameLocalDay(entry.consumedAt, day))
                .toList()
              ..sort((a, b) => a.consumedAt.compareTo(b.consumedAt));
        final weightItems =
            controller.weightEntries
                .where((entry) => isSameLocalDay(entry.recordedAt, day))
                .toList()
              ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

        return Scaffold(
          appBar: AppBar(title: Text(_title)),
          body: SafeArea(
            child: AppContentConstraint(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  Text(
                    '食事',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (foodItems.isEmpty)
                    AppEmptyState(
                      message: 'この日の食事記録はありません',
                      actionLabel: _canAdd ? '食事を追加' : null,
                      onAction: _canAdd ? () => _openFoodForm(context) : null,
                    )
                  else
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < foodItems.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xxs,
                              ),
                              onTap: () =>
                                  _openFoodForm(context, entry: foodItems[i]),
                              title: Text(foodItems[i].name),
                              subtitle: VerticalMacroDisplay(
                                leading: Text(
                                  _formatTime(foodItems[i].loggedAt),
                                ),
                                kcal: foodItems[i].kcalPerUnit == null
                                    ? null
                                    : foodItems[i].totalKcal,
                                proteinG: foodItems[i].proteinPerUnit == null
                                    ? null
                                    : foodItems[i].totalProteinG,
                                fatG: foodItems[i].fatPerUnit == null
                                    ? null
                                    : foodItems[i].totalFatG,
                                carbG: foodItems[i].carbPerUnit == null
                                    ? null
                                    : foodItems[i].totalCarbG,
                                showKcal: false,
                                trailing: Text(
                                  _foodEntryQuantityLine(foodItems[i]),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${formatNullableNutrient(foodItems[i].kcalPerUnit == null ? null : foodItems[i].totalKcal)} kcal',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: AppColors.primaryGreen,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                    ),
                                    onPressed: () => _confirmDeleteFood(
                                      context,
                                      foodItems[i],
                                    ),
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
                  Text(
                    'アルコール',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (alcoholItems.isEmpty)
                    AppEmptyState(
                      message: 'この日のアルコール記録はありません',
                      actionLabel: _canAdd ? 'アルコールを追加' : null,
                      onAction: _canAdd
                          ? () => _openAlcoholForm(context)
                          : null,
                    )
                  else
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < alcoholItems.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xxs,
                              ),
                              onTap: () => _openAlcoholForm(
                                context,
                                entry: alcoholItems[i],
                              ),
                              title: Text(alcoholItems[i].beverageName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${alcoholItems[i].amount}${alcoholItems[i].unit} / '
                                    '${alcoholItems[i].alcoholPercentage}%',
                                  ),
                                  Text(
                                    '純アルコール ${formatNullableNutrient(alcoholItems[i].pureAlcoholGrams, fractionDigits: 1)}g · '
                                    'アルコール由来 ${formatNullableNutrient(alcoholItems[i].alcoholCalories, fractionDigits: 0)}kcal',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.secondaryText,
                                        ),
                                  ),
                                  Text(_formatTime(alcoholItems[i].consumedAt)),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${formatNullableNutrient(alcoholItems[i].totalCalories, fractionDigits: 0)} kcal',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: AppColors.accentWine,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                    ),
                                    onPressed: () => _confirmDeleteAlcohol(
                                      context,
                                      alcoholItems[i],
                                    ),
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
                  Text(
                    '運動',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (exerciseItems.isEmpty)
                    AppEmptyState(
                      message: 'この日の運動記録はありません',
                      actionLabel: _canAdd ? '運動を追加' : null,
                      onAction: _canAdd
                          ? () => _openExerciseForm(context)
                          : null,
                    )
                  else
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < exerciseItems.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xxs,
                              ),
                              onTap: () => _openExerciseForm(
                                context,
                                entry: exerciseItems[i],
                              ),
                              title: Text(exerciseItems[i].name),
                              subtitle: Text(
                                '${_formatTime(exerciseItems[i].loggedAt)} · '
                                '${exerciseItems[i].durationMin} 分',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${exerciseItems[i].burnedKcal.toStringAsFixed(0)} kcal',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: AppColors.accentOrange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                    ),
                                    onPressed: () => _confirmDeleteExercise(
                                      context,
                                      exerciseItems[i],
                                    ),
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
                  Text(
                    '体重',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (weightItems.isEmpty)
                    AppEmptyState(
                      message: 'この日の体重記録はありません',
                      actionLabel: _canAdd ? '体重を追加' : null,
                      onAction: _canAdd ? () => _openWeightForm(context) : null,
                    )
                  else
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < weightItems.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xxs,
                              ),
                              onTap: () => _openWeightForm(
                                context,
                                entry: weightItems[i],
                              ),
                              title: Text(
                                '${weightItems[i].weightKg.toStringAsFixed(1)} kg',
                              ),
                              subtitle: Text(
                                _formatTime(weightItems[i].recordedAt),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                onPressed: () => _confirmDeleteWeight(
                                  context,
                                  weightItems[i],
                                ),
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
