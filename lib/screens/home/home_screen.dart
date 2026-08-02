import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../models/alcohol_entry.dart';
import '../../models/exercise_entry.dart';
import '../../models/food_entry.dart';
import '../../models/goal.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/history_grouping.dart';
import '../../utils/local_date.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/brand/app_logo.dart';
import '../../widgets/common/delete_with_undo.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_section_header.dart';
import '../../widgets/common/calorie_progress_ring.dart';
import '../../widgets/common/macro_progress_bar.dart';
import '../../widgets/layout/app_content_constraint.dart';
import '../../widgets/layout/app_responsive.dart';
import '../alcohol/alcohol_form_screen.dart';
import '../food/food_form_navigation.dart';
import '../exercise/exercise_form_screen.dart';
import '../settings/daily_calculation_explanation_screen.dart';
import '../weight/weight_record_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    this.foodFormBuilder,
    this.onOpenHistoryCalendar,
    this.onOpenWorkoutTab,
    this.onOpenWeightTab,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final FoodFormScreenBuilder? foodFormBuilder;
  final VoidCallback? onOpenHistoryCalendar;
  final VoidCallback? onOpenWorkoutTab;
  final VoidCallback? onOpenWeightTab;

  Future<void> _confirmDeleteFood(BuildContext context, FoodEntry entry) async {
    await confirmDeleteWithUndo<FoodEntry>(
      context: context,
      title: '削除確認',
      message: '「${entry.name}」を削除しますか？',
      snapshot: entry,
      onDelete: () => controller.deleteFood(entry.id),
      onRestore: (restored) => controller.addFood(restored),
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
      onRestore: (restored) => controller.addExercise(restored),
    );
  }

  void _openFoodForm(BuildContext context, {FoodEntry? entry}) {
    openFoodFormScreen(
      context,
      controller: controller,
      openFoodFactsService: openFoodFactsService,
      entry: entry,
      foodFormBuilder: foodFormBuilder,
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
      onRestore: (restored) => controller.addAlcohol(restored),
    );
  }

  void _openAlcoholForm(BuildContext context, {AlcoholEntry? entry}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            AlcoholFormScreen(controller: controller, entry: entry),
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

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
        .toList()
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
  }

  List<AlcoholEntry> _todayAlcoholEntries(List<AlcoholEntry> entries) {
    final now = DateTime.now();
    return entries
        .where((entry) => isSameLocalDay(entry.consumedAt, now))
        .toList()
      ..sort((a, b) => a.consumedAt.compareTo(b.consumedAt));
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
        .toList()
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
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
          return const Scaffold(body: AppEmptyState(message: 'データがありません'));
        }

        final todayFood = _todayFoodEntries(controller.foodEntries);
        final todayAlcohol = _todayAlcoholEntries(controller.alcoholEntries);
        final todayExercise = _todayExerciseEntries(controller.exerciseEntries);

        return Scaffold(
          body: SafeArea(
            child: AppContentConstraint(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: AppLogo(height: 30),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final twoColumn =
                            isDesktopLayout(context) &&
                            isWideSummaryLayout(constraints.maxWidth);
                        final ringCard = AppCard(
                          large: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm + 2,
                          ),
                          child: Column(
                            children: [
                              CalorieProgressRing(
                                intakeKcal: summary.intakeKcal,
                                targetKcal: summary.targetKcal,
                                remainingKcal: summary.remainingKcal,
                                isCalorieOverage: summary.isCalorieOverage,
                                calorieOverageKcal: summary.calorieOverageKcal,
                                size: twoColumn ? 132 : 148,
                                strokeWidth: 11,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                summary.isCalorieOverage
                                    ? '目標 ${summary.targetKcal.toStringAsFixed(0)} kcal / '
                                          '摂取 ${summary.intakeKcal.toStringAsFixed(0)} kcal（超過）'
                                    : '目標 ${summary.targetKcal.toStringAsFixed(0)} kcal / '
                                          '摂取 ${summary.intakeKcal.toStringAsFixed(0)} kcal',
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (context) =>
                                          DailyCalculationExplanationScreen(
                                            summary: summary,
                                          ),
                                    ),
                                  );
                                },
                                child: const Text('この数値の計算根拠'),
                              ),
                            ],
                          ),
                        );
                        final macroCard = AppCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          child: Column(
                            children: [
                              MacroProgressBar(
                                label: AppStrings.macroProtein,
                                intakeG: summary.intakeProteinG,
                                targetG: summary.targetProteinG,
                                color: AppColors.macroProtein,
                                compact: true,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              MacroProgressBar(
                                label: AppStrings.macroFat,
                                intakeG: summary.intakeFatG,
                                targetG: summary.targetFatG,
                                color: AppColors.macroFat,
                                compact: true,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              MacroProgressBar(
                                label: AppStrings.macroCarb,
                                intakeG: summary.intakeCarbG,
                                targetG: summary.targetCarbG,
                                color: AppColors.macroCarb,
                                compact: true,
                              ),
                            ],
                          ),
                        );

                        if (twoColumn) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: ringCard),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(child: macroCard),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ringCard,
                            const SizedBox(height: AppSpacing.sm),
                            macroCard,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _QuickActionsRow(
                      onAddFood: () => _openFoodForm(context),
                      onAddWorkout: () => _openExerciseForm(context),
                      onRecordWeight: () => _openWeightRecord(
                        context,
                        initialWeightKg: profile.weightKg,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '今日のサマリー',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _SummaryRow(
                            label: '消費 kcal',
                            value:
                                '${summary.exerciseBurnKcal.toStringAsFixed(0)} kcal',
                          ),
                          _SummaryRow(
                            label: '現在体重',
                            value: '${profile.weightKg.toStringAsFixed(1)} kg',
                          ),
                          _SummaryRow(
                            label: '目標',
                            value: _goalSummaryLabel(goal),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppSectionHeader(
                      title: '今日の食事',
                      actionLabel: onOpenHistoryCalendar != null ? '履歴' : null,
                      onAction: onOpenHistoryCalendar,
                    ),
                    if (todayFood.isEmpty)
                      const AppEmptyState(message: '登録された食事はありません')
                    else
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < todayFood.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              _TodayFoodTile(
                                entry: todayFood[i],
                                timeLabel: _formatTime(todayFood[i].loggedAt),
                                onTap: () =>
                                    _openFoodForm(context, entry: todayFood[i]),
                                onDelete: () =>
                                    _confirmDeleteFood(context, todayFood[i]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    AppSectionHeader(title: '今日のアルコール'),
                    if (todayAlcohol.isEmpty)
                      const AppEmptyState(message: '登録されたアルコールはありません')
                    else
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < todayAlcohol.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              _TodayAlcoholTile(
                                entry: todayAlcohol[i],
                                timeLabel: _formatTime(
                                  todayAlcohol[i].consumedAt,
                                ),
                                onTap: () => _openAlcoholForm(
                                  context,
                                  entry: todayAlcohol[i],
                                ),
                                onDelete: () => _confirmDeleteAlcohol(
                                  context,
                                  todayAlcohol[i],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    AppSectionHeader(title: '今日の運動'),
                    if (todayExercise.isEmpty)
                      const AppEmptyState(message: '登録された運動はありません')
                    else
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < todayExercise.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              _TodayExerciseTile(
                                entry: todayExercise[i],
                                timeLabel: _formatTime(
                                  todayExercise[i].loggedAt,
                                ),
                                onTap: () => _openExerciseForm(
                                  context,
                                  entry: todayExercise[i],
                                ),
                                onDelete: () => _confirmDeleteExercise(
                                  context,
                                  todayExercise[i],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onAddFood,
    required this.onAddWorkout,
    required this.onRecordWeight,
  });

  final VoidCallback onAddFood;
  final VoidCallback onAddWorkout;
  final VoidCallback onRecordWeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.restaurant_outlined,
            label: '食事追加',
            onTap: onAddFood,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.directions_run_outlined,
            label: '運動追加',
            onTap: onAddWorkout,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.monitor_weight_outlined,
            label: '体重記録',
            onTap: onRecordWeight,
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.xxs,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: AppColors.primaryGreen),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
            ),
          ),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _TodayFoodTile extends StatelessWidget {
  const _TodayFoodTile({
    required this.entry,
    required this.timeLabel,
    required this.onTap,
    required this.onDelete,
  });

  final FoodEntry entry;
  final String timeLabel;
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
      subtitle: Text(timeLabel),
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

class _TodayAlcoholTile extends StatelessWidget {
  const _TodayAlcoholTile({
    required this.entry,
    required this.timeLabel,
    required this.onTap,
    required this.onDelete,
  });

  final AlcoholEntry entry;
  final String timeLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      onTap: onTap,
      title: Text(entry.beverageName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${entry.amount}${entry.unit} / ${entry.alcoholPercentage}%'),
          Text(
            '純アルコール ${formatNullableNutrient(entry.pureAlcoholGrams, fractionDigits: 1)}g · '
            'アルコール由来 ${formatNullableNutrient(entry.alcoholCalories, fractionDigits: 0)}kcal',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.secondaryText),
          ),
          Text(timeLabel),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${formatNullableNutrient(entry.totalCalories, fractionDigits: 0)} kcal',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.accentWine,
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

class _TodayExerciseTile extends StatelessWidget {
  const _TodayExerciseTile({
    required this.entry,
    required this.timeLabel,
    required this.onTap,
    required this.onDelete,
  });

  final ExerciseEntry entry;
  final String timeLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      onTap: onTap,
      title: Text(entry.name),
      subtitle: Text(timeLabel),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${entry.burnedKcal.toStringAsFixed(0)} kcal',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.accentOrange,
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
