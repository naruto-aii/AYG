import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/calculation/landing_guidance.dart';
import '../../models/alcohol_entry.dart';
import '../../models/daily_summary.dart';
import '../../models/exercise_entry.dart';
import '../../models/food_entry.dart';
import '../../services/open_food_facts_service.dart';
import '../../services/share_card_content.dart';
import '../../services/share_sheet_client.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/local_date.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/announcements/home_announcements_entry.dart';
import '../../widgets/brand/app_logo.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/delete_with_undo.dart';
import '../../widgets/design/calorie_ring.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_icon.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/home_parts.dart';
import '../../widgets/layout/active_tab_listenable_builder.dart';
import '../../widgets/share/share_composer.dart';
import '../../widgets/share/share_icon_button.dart';
import '../alcohol/alcohol_form_screen.dart';
import '../coach/daily_coach_screen.dart';
import '../food/food_memo_dialog.dart';
import '../food/recent_foods_screen.dart';
import '../subscription/plus_gate.dart';
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
    this.shareCard,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final FoodFormScreenBuilder? foodFormBuilder;
  final VoidCallback? onOpenHistoryCalendar;
  final VoidCallback? onOpenWorkoutTab;
  final VoidCallback? onOpenWeightTab;

  /// テストが共有シートの代わりに受け取る。未指定なら iOS の共有シート。
  final ShareCardRequest? shareCard;

  @override
  Widget build(BuildContext context) {
    return ActiveTabListenableBuilder(
      listenable: controller,
      builder: (context) {
        final profile = controller.profile;
        final goal = controller.goal;
        final summary = controller.summary;

        if (profile == null || goal == null || summary == null) {
          return const DesignPage(body: AppEmptyState(message: 'データがありません'));
        }

        final todayFood = _todayFood(controller.foodEntries);
        final todayAlcohol = _todayAlcohol(controller.alcoholEntries);
        final todayExercise = _todayExercise(controller.exerciseEntries);

        return DesignPage(
          header: _Header(onShare: () => _shareToday(context)),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HomeAnnouncementsEntry(),
              const SizedBox(height: 8),
              Center(child: _ring(summary)),
              const SizedBox(height: 12),
              _coachEntry(context),
              const SizedBox(height: 8),
              _stats(summary),
              const SizedBox(height: 4),
              _weightUsage(controller),
              const SizedBox(height: 4),
              _calculationLink(context, summary),
              if (summary.energyBreakdown?.guidance != null) ...[
                const SizedBox(height: 8),
                _guidanceCard(context, summary.energyBreakdown!.guidance!),
              ],
              const SizedBox(height: 6),
              _macroCard(summary),
              const SizedBox(height: 8),
              _quickAdd(context, profile.weightKg),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _openRecentFoods(context),
                  child: const Text('直近3日の食品'),
                ),
              ),
              Text(
                '直近3日からの追加と、食事のメモはカロナビ+です。',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
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
      value:
          (summary.isCalorieOverage
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

  Widget _weightUsage(AppController controller) {
    final selection = controller.currentWeightSelection;
    final noteStyle = AppTypography.caption.copyWith(
      color: AppColors.textMuted,
    );
    return Column(
      children: [
        Text(
          selection.usageLabel,
          textAlign: TextAlign.center,
          style: noteStyle,
        ),
        if (selection.healthUpdateStoppedNote != null)
          Text(
            selection.healthUpdateStoppedNote!,
            textAlign: TextAlign.center,
            style: noteStyle,
          ),
        if (selection.staleRecordPrompt != null)
          Text(
            selection.staleRecordPrompt!,
            textAlign: TextAlign.center,
            style: noteStyle.copyWith(color: AppColors.orange500),
          ),
      ],
    );
  }

  Widget _guidanceCard(BuildContext context, LandingGuidance guidance) {
    final actions = <LandingGuidanceAction>[
      guidance.recommended,
      if (guidance.alternative != null) guidance.alternative!,
    ];
    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('目標日には届きません', style: AppTypography.titleM),
          const SizedBox(height: 6),
          Text(guidance.message, style: AppTypography.bodyS),
          const SizedBox(height: 10),
          for (final action in actions) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => controllerAction(context, action),
                child: Text(
                  action == guidance.recommended
                      ? '推奨: ${guidance.labelFor(action)}'
                      : guidance.labelFor(action),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void controllerAction(BuildContext context, LandingGuidanceAction action) {
    final controller = this.controller;
    () async {
      await controller.applyLandingSuggestion(action);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('目標を更新しました')));
    }();
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

  Widget _coachEntry(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: DesignButton(
        label: '今日のコーチ',
        height: 52,
        style: DesignButtonStyle.secondary,
        showTrailingIcon: false,
        leading: SvgPicture.asset(
          'assets/illustrations/coach_mark.svg',
          width: 28,
          height: 28,
        ),
        onPressed: () => _openCoach(context),
      ),
    );
  }

  Future<void> _openCoach(BuildContext context) async {
    final added = await Navigator.of(context).push<CoachSavedKind>(
      MaterialPageRoute<CoachSavedKind>(
        builder: (context) => DailyCoachScreen(controller: controller),
      ),
    );
    if (!context.mounted) {
      return;
    }
    final message = switch (added) {
      CoachSavedKind.meal => '食事に追加しました',
      CoachSavedKind.exercise => '運動に追加しました',
      null => null,
    };
    if (message == null) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _foodSection(BuildContext context, List<FoodEntry> entries) {
    return _sectionCard(
      icon: AppIcons.meal,
      title: '今日の食事',
      actionLabel: onOpenHistoryCalendar != null ? 'すべて見る' : null,
      onAction: onOpenHistoryCalendar,
      emptyMessage: '登録された食事はありません',
      rows: [
        for (final entry in entries) ...[
          DesignListRow(
            icon: AppIcons.meal,
            time: _time(entry.loggedAt),
            title: entry.name,
            value: formatNullableNutrient(
              entry.kcalPerUnit == null ? null : entry.totalKcal,
            ),
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
          if (entry.memo != null)
            Padding(
              padding: const EdgeInsets.only(left: 48, bottom: 4),
              child: Text(
                entry.memo!,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _editFoodMemo(context, entry),
              child: Text(entry.memo == null ? 'メモ' : 'メモを編集'),
            ),
          ),
        ],
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

  Future<void> _openRecentFoods(BuildContext context) async {
    final allowed = await ensureCalonaviPlus(
      context,
      controller,
      message: '直近3日の食品からの追加は、カロナビ+です。',
    );
    if (!allowed || !context.mounted) {
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => RecentFoodsScreen(controller: controller),
      ),
    );
  }

  Future<void> _editFoodMemo(BuildContext context, FoodEntry entry) async {
    final allowed = await ensureCalonaviPlus(
      context,
      controller,
      message: '食品のメモは、カロナビ+です。',
    );
    if (!allowed || !context.mounted) {
      return;
    }
    final memo = await askFoodMemo(context, initial: entry.memo);
    if (memo == null || !context.mounted) {
      return;
    }
    final saved = await controller.updateFoodMemo(entry, memo);
    if (!saved && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('メモを保存できませんでした')));
    }
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
                style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
              ),
            )
          else
            ...rows,
        ],
      ),
    );
  }

  Future<void> _shareToday(BuildContext context) async {
    final summary = controller.summary;
    if (summary == null) {
      return;
    }
    final now = DateTime.now();
    final streak = currentRecordingStreakDays(
      foodLoggedAts: controller.foodEntries.map((entry) => entry.loggedAt),
      exerciseLoggedAts: controller.exerciseEntries.map(
        (entry) => entry.loggedAt,
      ),
      alcoholConsumedAts: controller.alcoholEntries.map(
        (entry) => entry.consumedAt,
      ),
      weightEntries: controller.weightEntries,
      now: now,
    );
    await showShareComposer(
      context: context,
      kinds: const [ShareCardKind.meal, ShareCardKind.streak],
      initialKind: ShareCardKind.meal,
      showsWeightPrivacy: false,
      build: ({required kind, required format, required privacy}) {
        return switch (kind) {
          ShareCardKind.meal => buildMealShareCard(
            summary: summary,
            day: now,
            format: format,
          ),
          ShareCardKind.streak => buildStreakShareCard(
            days: streak,
            day: now,
            format: format,
          ),
          ShareCardKind.weight => buildMealShareCard(
            summary: summary,
            day: now,
            format: format,
          ),
        };
      },
      onShare: (content, boundaryKey) {
        final override = shareCard;
        if (override != null) {
          return override(content, boundaryKey);
        }
        final action = shareScreenAction(content.kind);
        return sendShareCard(
          content: content,
          boundaryKey: boundaryKey,
          onSent: () {
            controller.recordScreenAction(
              screen: action.screen,
              action: action.action,
            );
          },
        );
      },
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

/// 左にロゴ、右に小さな共有。
class _Header extends StatelessWidget {
  const _Header({required this.onShare});

  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 8, top: 4),
        child: Row(
          children: [
            const AppLogo(markSize: 27.5, titleSize: 20, gap: 14),
            const Spacer(),
            ShareIconButton(tooltip: '記録を共有', onPressed: onShare),
          ],
        ),
      ),
    );
  }
}
