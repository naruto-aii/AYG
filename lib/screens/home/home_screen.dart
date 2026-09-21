import 'package:flutter/material.dart';

import '../../models/alcohol_entry.dart';
import '../../models/daily_summary.dart';
import '../../models/exercise_entry.dart';
import '../../models/food_entry.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/local_date.dart';
import '../../widgets/brand/app_logo.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/delete_with_undo.dart';
import '../../widgets/design/calorie_ring.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_icon.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/home_parts.dart';
import '../alcohol/alcohol_form_screen.dart';
import '../exercise/exercise_form_screen.dart';
import '../food/food_form_navigation.dart';
import '../settings/daily_calculation_explanation_screen.dart';
import '../weight/weight_record_screen.dart';

/// ホーム。
///
/// Figma: SP / 05 ホーム（25:427）
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final profile = controller.profile;
        final goal = controller.goal;
        final summary = controller.summary;

        if (profile == null || goal == null || summary == null) {
          return const DesignPage(
            body: AppEmptyState(message: 'データがありません'),
          );
        }

        final todayFood = _todayFood(controller.foodEntries);
        final todayAlcohol = _todayAlcohol(controller.alcoholEntries);
        final todayExercise = _todayExercise(controller.exerciseEntries);

        return DesignPage(
          header: _Header(),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _ring(summary)),
              const SizedBox(height: 4),
              _stats(summary),
              const SizedBox(height: 4),
              _calculationLink(context, summary),
              const SizedBox(height: 6),
              _macroCard(summary),
              const SizedBox(height: 8),
              _quickAdd(context, profile.weightKg),
              const SizedBox(height: 8),
              _foodSection(context, todayFood),
              const SizedBox(height: 8),
              _alcoholSection(context, todayAlcohol),
              const SizedBox(height: 6),
              _exerciseSection(context, todayExercise),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // --- セクション --------------------------------------------------------

  Widget _ring(DailySummary summary) {
    final target = summary.targetKcal;
    return CalorieRing(
      label: summary.isCalorieOverage ? '超過' : '今日あと',
      value: (summary.isCalorieOverage
              ? summary.calorieOverageKcal
              : summary.remainingKcal.clamp(0, double.infinity))
          .toStringAsFixed(0),
      progress: target > 0 ? summary.intakeKcal / target : 0,
      progressColor: summary.isCalorieOverage ? AppColors.orange500 : null,
    );
  }

  Widget _stats(DailySummary summary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: StatItem(label: '目標', value: _comma(summary.targetKcal)),
        ),
        Expanded(
          child: StatItem(label: '摂取', value: _comma(summary.intakeKcal)),
        ),
        Expanded(
          child: StatItem(
            label: '運動',
            value: '+${_comma(summary.exerciseBurnKcal)}',
          ),
        ),
      ],
    );
  }

  Widget _calculationLink(BuildContext context, DailySummary summary) {
    return Center(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) =>
                DailyCalculationExplanationScreen(summary: summary),
          ),
        ),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'この数値の計算根拠',
                style: AppTypography.link.copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textBrand,
                ),
              ),
              const DesignIcon(
                Symbols.chevron_right_rounded,
                size: 16,
                color: AppColors.iconPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _macroCard(DailySummary summary) {
    return DesignCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PFCバランス', style: AppTypography.titleL),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: MacroBar(
                  icon: AppIcons.meat,
                  label: 'タンパク質',
                  remainingG: _remaining(
                    summary.intakeProteinG,
                    summary.targetProteinG,
                  ),
                  targetG: summary.targetProteinG.toStringAsFixed(0),
                  progress: _ratio(
                    summary.intakeProteinG,
                    summary.targetProteinG,
                  ),
                  color: AppColors.macroProtein,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MacroBar(
                  icon: AppIcons.avocado,
                  label: '脂質',
                  remainingG: _remaining(
                    summary.intakeFatG,
                    summary.targetFatG,
                  ),
                  targetG: summary.targetFatG.toStringAsFixed(0),
                  progress: _ratio(summary.intakeFatG, summary.targetFatG),
                  color: AppColors.macroFat,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MacroBar(
                  icon: AppIcons.rice,
                  label: '炭水化物',
                  remainingG: _remaining(
                    summary.intakeCarbG,
                    summary.targetCarbG,
                  ),
                  targetG: summary.targetCarbG.toStringAsFixed(0),
                  progress: _ratio(summary.intakeCarbG, summary.targetCarbG),
                  color: AppColors.macroCarb,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickAdd(BuildContext context, double currentWeightKg) {
    return Row(
      children: [
        Expanded(
          child: QuickAddCard(
            icon: AppIcons.meal,
            label: '食事追加',
            onTap: () => _openFoodForm(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: QuickAddCard(
            icon: AppIcons.exercise,
            label: '運動追加',
            onTap: () => _openExerciseForm(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: QuickAddCard(
            icon: AppIcons.scale,
            label: '体重記録',
            onTap: () => _openWeightRecord(context, currentWeightKg),
          ),
        ),
      ],
    );
  }

  Widget _foodSection(BuildContext context, List<FoodEntry> entries) {
    return _sectionCard(
      icon: AppIcons.meal,
      title: '今日の食事',
      actionLabel: onOpenHistoryCalendar != null ? 'すべて見る' : null,
      onAction: onOpenHistoryCalendar,
      emptyMessage: '登録された食事はありません',
      rows: [
        for (final entry in entries)
          DesignListRow(
            icon: AppIcons.meal,
            time: _time(entry.loggedAt),
            title: entry.name,
            value: entry.kcalPerUnit == null
                ? '—'
                : entry.totalKcal.toStringAsFixed(0),
            onTap: () => _openFoodForm(context, entry: entry),
            onLongPress: () => confirmDeleteWithUndo<FoodEntry>(
              context: context,
              title: '削除確認',
              message: '「${entry.name}」を削除しますか？',
              snapshot: entry,
              onDelete: () => controller.deleteFood(entry.id),
              onRestore: (restored) => controller.restoreFoodEntry(restored),
            ),
          ),
      ],
    );
  }

  Widget _alcoholSection(BuildContext context, List<AlcoholEntry> entries) {
    return _sectionCard(
      icon: AppIcons.alcohol,
      title: '今日のアルコール',
      actionLabel: onOpenHistoryCalendar != null ? 'すべて見る' : null,
      onAction: onOpenHistoryCalendar,
      emptyMessage: '登録されたアルコールはありません',
      rows: [
        for (final entry in entries)
          DesignListRow(
            icon: AppIcons.alcohol,
            time: _time(entry.consumedAt),
            title: entry.beverageName,
            value: entry.totalCalories.toStringAsFixed(0),
            onTap: () => _openAlcoholForm(context, entry: entry),
            onLongPress: () => confirmDeleteWithUndo<AlcoholEntry>(
              context: context,
              title: '削除確認',
              message: '「${entry.beverageName}」を削除しますか？',
              snapshot: entry,
              onDelete: () => controller.deleteAlcohol(entry.id),
              onRestore: (restored) => controller.restoreAlcoholEntry(restored),
            ),
          ),
      ],
    );
  }

  Widget _exerciseSection(BuildContext context, List<ExerciseEntry> entries) {
    return _sectionCard(
      icon: AppIcons.exercise,
      title: '今日の運動',
      actionLabel: onOpenWorkoutTab != null ? 'すべて見る' : null,
      onAction: onOpenWorkoutTab,
      emptyMessage: '登録された運動はありません',
      rows: [
        for (final entry in entries)
          DesignListRow(
            icon: AppIcons.exercise,
            time: _time(entry.loggedAt),
            title: entry.name,
            value: '+${entry.effectiveNetKcal.toStringAsFixed(0)}',
            onTap: () => _openExerciseForm(context, entry: entry),
            onLongPress: () => confirmDeleteWithUndo<ExerciseEntry>(
              context: context,
              title: '削除確認',
              message: '「${entry.name}」を削除しますか？',
              snapshot: entry,
              onDelete: () => controller.deleteExercise(entry.id),
              onRestore: (restored) =>
                  controller.restoreExerciseEntry(restored),
            ),
          ),
      ],
    );
  }

  Widget _sectionCard({
    required String icon,
    required String title,
    required String emptyMessage,
    required List<Widget> rows,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return DesignCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignSectionHeader(
            icon: icon,
            title: title,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
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
        ],
      ),
    );
  }

  // --- 画面遷移 ----------------------------------------------------------

  void _openFoodForm(BuildContext context, {FoodEntry? entry}) {
    openFoodFormScreen(
      context,
      controller: controller,
      openFoodFactsService: openFoodFactsService,
      entry: entry,
      foodFormBuilder: foodFormBuilder,
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

  void _openWeightRecord(BuildContext context, double currentWeightKg) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => WeightRecordScreen(
          controller: controller,
          initialWeightKg: currentWeightKg,
        ),
      ),
    );
  }

  // --- 小物 --------------------------------------------------------------

  static String _time(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  static String _comma(double value) {
    final digits = value.round().abs().toString();
    final buffer = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static String _remaining(double intake, double target) {
    return (target - intake).clamp(0, double.infinity).toStringAsFixed(0);
  }

  static double _ratio(double intake, double target) {
    return target > 0 ? intake / target : 0;
  }

  static List<FoodEntry> _todayFood(List<FoodEntry> entries) {
    final now = DateTime.now();
    return entries.where((e) => isSameLocalDay(e.loggedAt, now)).toList()
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
  }

  static List<AlcoholEntry> _todayAlcohol(List<AlcoholEntry> entries) {
    final now = DateTime.now();
    return entries.where((e) => isSameLocalDay(e.consumedAt, now)).toList()
      ..sort((a, b) => a.consumedAt.compareTo(b.consumedAt));
  }

  static List<ExerciseEntry> _todayExercise(List<ExerciseEntry> entries) {
    final now = DateTime.now();
    return entries.where((e) => isSameLocalDay(e.loggedAt, now)).toList()
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
  }
}

/// Figma: header（左上にロゴだけ）。
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 48,
      child: Padding(
        padding: EdgeInsets.only(left: 16, top: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          // Figma の Logo/Horizontal はマークを 40 の箱に収めている。
          child: AppLogo(markSize: 27.5, titleSize: 20, gap: 14),
        ),
      ),
    );
  }
}
