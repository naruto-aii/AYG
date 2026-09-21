import 'package:flutter/material.dart';

import '../../models/food_entry.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../models/alcohol_entry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/history_grouping.dart';
import '../../utils/local_date.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/common/delete_with_undo.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_icon.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/home_parts.dart';
import '../../widgets/history/history_tab_body.dart';
import '../alcohol/alcohol_form_screen.dart';
import '../history/history_calendar_screen.dart';
import '../meal_template/meal_template_list_screen.dart';
import 'food_form_navigation.dart';

class FoodTabScreen extends StatefulWidget {
  const FoodTabScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    this.foodFormBuilder,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final FoodFormScreenBuilder? foodFormBuilder;

  @override
  State<FoodTabScreen> createState() => _FoodTabScreenState();
}

class _FoodTabScreenState extends State<FoodTabScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = localDayStart(DateTime.now());
  }

  DateTime get _initialLoggedAtForNewEntry =>
      initialLoggedAtForSelectedDay(_selectedDate);

  DateTime get _initialConsumedAtForNewEntry => _initialLoggedAtForNewEntry;

  void _openHistoryCalendar() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => HistoryCalendarScreen(
          controller: widget.controller,
          openFoodFactsService: widget.openFoodFactsService,
          foodFormBuilder: widget.foodFormBuilder,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteFood(BuildContext context, FoodEntry entry) async {
    await confirmDeleteWithUndo<FoodEntry>(
      context: context,
      title: '削除確認',
      message: '「${entry.name}」を削除しますか？',
      snapshot: entry,
      onDelete: () => widget.controller.deleteFood(entry.id),
      onRestore: (restored) => widget.controller.restoreFoodEntry(restored),
    );
  }

  void _openFoodForm(BuildContext context, {FoodEntry? entry}) {
    if (entry == null && !canAddRecordOnDay(_selectedDate)) {
      showFutureDayAddBlockedSnackBar(context);
      return;
    }

    openFoodFormScreen(
      context,
      controller: widget.controller,
      openFoodFactsService: widget.openFoodFactsService,
      entry: entry,
      initialLoggedAt: entry == null ? _initialLoggedAtForNewEntry : null,
      foodFormBuilder: widget.foodFormBuilder,
    );
  }

  void _openAlcoholForm(BuildContext context) {
    if (!canAddRecordOnDay(_selectedDate)) {
      showFutureDayAddBlockedSnackBar(context);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AlcoholFormScreen(
          controller: widget.controller,
          initialConsumedAt: _initialConsumedAtForNewEntry,
        ),
      ),
    );
  }

  void _openAlcoholEdit(BuildContext context, AlcoholEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            AlcoholFormScreen(controller: widget.controller, entry: entry),
      ),
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
      onDelete: () => widget.controller.deleteAlcohol(entry.id),
      onRestore: (restored) => widget.controller.restoreAlcoholEntry(restored),
    );
  }

  void _openTemplates() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            MealTemplateListScreen(controller: widget.controller),
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
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final d = _selectedDate;
    final base = '${d.month}月${d.day}日（${weekdays[d.weekday - 1]}）';
    return isSameLocalDay(d, DateTime.now()) ? '今日 $base' : base;
  }

  static String _time(DateTime t) =>
      '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final day = _selectedDate;
        final foods = sortFoodEntriesByLoggedAt(
          widget.controller.foodEntries
              .where((e) => isSameLocalDay(e.loggedAt, day))
              .toList(),
        );
        final alcohols =
            widget.controller.alcoholEntries
                .where((e) => isSameLocalDay(e.consumedAt, day))
                .toList()
              ..sort((a, b) => a.consumedAt.compareTo(b.consumedAt));
        final isToday = isSameLocalDay(day, DateTime.now());
        final canAdd = canAddRecordOnDay(day);
        final dayWord = isToday ? '今日' : 'この日';

        return DesignPage(
          bottomBar: DesignButton(
            label: '食事を追加',
            onPressed: canAdd ? () => _openFoodForm(context) : null,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesignTitleBlock(
                title: '食事',
                subtitle: '今日食べたものを、さっと記録。',
                showBack: false,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '食事テンプレート',
                      onPressed: _openTemplates,
                      icon: const AppIcon(
                        AppIcons.template,
                        size: 24,
                        color: AppColors.iconPrimary,
                      ),
                    ),
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
              // Figma: 日付の送り（日付を押すとカレンダー）
              DesignCard(
                elevated: false,
                radius: 20,
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
                        onTap: _openHistoryCalendar,
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
              const SizedBox(height: 16),
              DesignSectionHeader(icon: AppIcons.meal, title: '$dayWordの食事'),
              const SizedBox(height: 4),
              if (foods.isEmpty)
                _empty('$dayWordの食事記録はありません')
              else
                for (final e in foods)
                  DesignListRow(
                    icon: AppIcons.meal,
                    time: _time(e.loggedAt),
                    title: e.name,
                    value: formatNullableNutrient(
                      e.kcalPerUnit == null ? null : e.totalKcal,
                    ),
                    onTap: () => _openFoodForm(context, entry: e),
                    onLongPress: () => _confirmDeleteFood(context, e),
                  ),
              const SizedBox(height: 16),
              DesignSectionHeader(
                icon: AppIcons.alcohol,
                title: '$dayWordのアルコール',
                actionLabel: canAdd ? 'アルコールを追加' : null,
                onAction: canAdd ? () => _openAlcoholForm(context) : null,
              ),
              const SizedBox(height: 4),
              if (alcohols.isEmpty)
                _empty('$dayWordのアルコール記録はありません')
              else
                for (final e in alcohols)
                  DesignListRow(
                    icon: AppIcons.alcohol,
                    time: _time(e.consumedAt),
                    title: e.beverageName,
                    value: e.totalCalories.toStringAsFixed(0),
                    onTap: () => _openAlcoholEdit(context, e),
                    onLongPress: () => _confirmDeleteAlcohol(context, e),
                  ),
              const SizedBox(height: 16),
              Text(
                '記録は長押しで削除できます。',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _empty(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
      ),
    );
  }
}
