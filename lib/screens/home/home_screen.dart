import 'package:flutter/material.dart';

import '../../models/exercise_entry.dart';
import '../../models/food_entry.dart';
import '../../models/goal.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/history_grouping.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/add_action_sheet.dart';
import '../../widgets/entry_list_tile.dart';
import '../../widgets/home/remaining_macros_section.dart';
import '../../widgets/home/responsive_summary_grid.dart';
import '../../widgets/home/today_progress_bar.dart';
import '../../widgets/summary_card.dart';
import '../exercise/exercise_form_screen.dart';
import '../food/food_form_screen.dart';
import '../weight/weight_record_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;

  Future<void> _confirmDeleteFood(BuildContext context, FoodEntry entry) async {
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
      controller.deleteFood(entry.id);
    }
  }

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

  void _openFoodForm(BuildContext context, {FoodEntry? entry}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => FoodFormScreen(
          controller: controller,
          openFoodFactsService: openFoodFactsService,
          entry: entry,
        ),
      ),
    );
  }

  void _openExerciseForm(BuildContext context, {ExerciseEntry? entry}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            ExerciseFormScreen(controller: controller, entry: entry),
      ),
    );
  }

  void _openWeightRecord(BuildContext context, {double? initialWeightKg}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => WeightRecordScreen(
          controller: controller,
          initialWeightKg: initialWeightKg,
        ),
      ),
    );
  }

  void _showAddMenu(BuildContext context, {double? currentWeightKg}) {
    showAddActionSheet(
      context,
      onAddFood: () => _openFoodForm(context),
      onAddWorkout: () => _openExerciseForm(context),
      onRecordWeight: () =>
          _openWeightRecord(context, initialWeightKg: currentWeightKg),
    );
  }

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

  double _remainingMacro(double target, double intake) {
    return (target - intake).clamp(0, double.infinity);
  }

  String _goalSummaryLabel(Goal goal) {
    final daysLeft = daysUntilGoalDate(goal.targetDate);
    final daysText = daysLeft >= 0 ? 'あと $daysLeft 日' : '期限超過';
    return '${goal.type.label} / 目標日まで$daysText';
  }

  List<FoodEntry> _todayFoodEntries(List<FoodEntry> entries) {
    final now = DateTime.now();
    return entries
        .where(
          (entry) =>
              entry.loggedAt.year == now.year &&
              entry.loggedAt.month == now.month &&
              entry.loggedAt.day == now.day,
        )
        .toList();
  }

  List<ExerciseEntry> _todayExerciseEntries(List<ExerciseEntry> entries) {
    final now = DateTime.now();
    return entries
        .where(
          (entry) =>
              entry.loggedAt.year == now.year &&
              entry.loggedAt.month == now.month &&
              entry.loggedAt.day == now.day,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final profile = controller.profile;
        final goal = controller.goal;
        final summary = controller.summary;

        if (profile == null || goal == null || summary == null) {
          return const Scaffold(body: Center(child: Text('データがありません')));
        }

        final progressValue = summary.targetKcal > 0
            ? (summary.intakeKcal / summary.targetKcal).clamp(0.0, 1.0)
            : 0.0;
        final todayFood = _todayFoodEntries(controller.foodEntries);
        final todayExercise = _todayExerciseEntries(controller.exerciseEntries);

        return Scaffold(
          appBar: AppBar(title: const Text('ホーム')),
          floatingActionButton: FloatingActionButton(
            onPressed: () =>
                _showAddMenu(context, currentWeightKg: profile.weightKg),
            child: const Icon(Icons.add),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RemainingKcalHero(remainingKcal: summary.remainingKcal),
                  const SizedBox(height: AppSpacing.md),
                  RemainingMacrosSection(
                    remainingProteinG: _remainingMacro(
                      summary.targetProteinG,
                      summary.intakeProteinG,
                    ),
                    remainingCarbG: _remainingMacro(
                      summary.targetCarbG,
                      summary.intakeCarbG,
                    ),
                    remainingFatG: _remainingMacro(
                      summary.targetFatG,
                      summary.intakeFatG,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TodayProgressBar(
                    intakeKcal: summary.intakeKcal,
                    targetKcal: summary.targetKcal,
                    progressValue: progressValue,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ResponsiveSummaryGrid(
                    cards: [
                      SummaryCard(
                        title: '摂取 kcal',
                        value: '${summary.intakeKcal.toStringAsFixed(0)} kcal',
                        icon: Icons.restaurant,
                      ),
                      SummaryCard(
                        title: '消費 kcal',
                        value:
                            '${summary.exerciseBurnKcal.toStringAsFixed(0)} kcal',
                        icon: Icons.local_fire_department,
                      ),
                      SummaryCard(
                        title: '現在体重',
                        value: '${profile.weightKg.toStringAsFixed(1)} kg',
                        icon: Icons.monitor_weight_outlined,
                      ),
                      SummaryCard(
                        title: '目標',
                        value: _goalSummaryLabel(goal),
                        icon: Icons.flag_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('今日の食事', style: AppTextStyles.sectionTitle(context)),
                  const SizedBox(height: AppSpacing.md),
                  if (todayFood.isEmpty)
                    const _EmptySectionMessage(message: '登録された食事はありません')
                  else
                    ...todayFood.map(
                      (entry) => EntryListTile(
                        title: entry.name,
                        subtitle: _foodEntrySubtitle(entry),
                        leadingIcon: Icons.restaurant,
                        onTap: () => _openFoodForm(context, entry: entry),
                        onDelete: () => _confirmDeleteFood(context, entry),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('今日の運動', style: AppTextStyles.sectionTitle(context)),
                  const SizedBox(height: AppSpacing.md),
                  if (todayExercise.isEmpty)
                    const _EmptySectionMessage(message: '登録された運動はありません')
                  else
                    ...todayExercise.map(
                      (entry) => EntryListTile(
                        title: entry.name,
                        subtitle:
                            '${entry.burnedKcal.toStringAsFixed(0)} kcal / '
                            '${entry.durationMin} 分',
                        leadingIcon: Icons.fitness_center,
                        onTap: () => _openExerciseForm(context, entry: entry),
                        onDelete: () => _confirmDeleteExercise(context, entry),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptySectionMessage extends StatelessWidget {
  const _EmptySectionMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
