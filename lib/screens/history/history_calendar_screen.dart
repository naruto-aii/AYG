import 'package:flutter/material.dart';

import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/history_calendar_markers.dart';
import '../../utils/local_date.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_icon.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/home_parts.dart';
import '../food/food_form_navigation.dart';
import 'day_history_screen.dart';

/// 月表示の履歴カレンダー。日付タップで日別履歴へ遷移する。
class HistoryCalendarScreen extends StatefulWidget {
  const HistoryCalendarScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    this.foodFormBuilder,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final FoodFormScreenBuilder? foodFormBuilder;

  @override
  State<HistoryCalendarScreen> createState() => _HistoryCalendarScreenState();
}

class _HistoryCalendarScreenState extends State<HistoryCalendarScreen> {
  late DateTime _focusedMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDay = localDayStart(now);
  }

  /// 1回目のタップで選び、選ばれている日をもう一度押すと日別の記録を開く。
  void _onDayTap(DateTime day) {
    final start = localDayStart(day);
    if (isSameLocalDay(start, _selectedDay)) {
      _openDayHistory(start);
      return;
    }
    setState(() => _selectedDay = start);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
    });
  }

  void _openDayHistory(DateTime day) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => DayHistoryScreen(
          controller: widget.controller,
          openFoodFactsService: widget.openFoodFactsService,
          selectedDay: day,
          foodFormBuilder: widget.foodFormBuilder,
        ),
      ),
    );
  }

  String _monthLabel(DateTime month) => '${month.year}年 ${month.month}月';

  static String _time(DateTime t) =>
      '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

  List<Widget> _dayRows() {
    final day = _selectedDay;
    final rows = <({DateTime at, Widget row})>[];
    void open() => _openDayHistory(day);

    for (final e in widget.controller.foodEntries) {
      if (!isSameLocalDay(e.loggedAt, day)) continue;
      rows.add((
        at: e.loggedAt,
        row: DesignListRow(
          icon: AppIcons.meal,
          time: _time(e.loggedAt),
          title: e.name,
          value: formatNullableNutrient(
            e.kcalPerUnit == null ? null : e.totalKcal,
          ),
          onTap: open,
        ),
      ));
    }
    for (final e in widget.controller.exerciseEntries) {
      if (!isSameLocalDay(e.loggedAt, day)) continue;
      rows.add((
        at: e.loggedAt,
        row: DesignListRow(
          icon: AppIcons.exercise,
          time: _time(e.loggedAt),
          title: e.name,
          value: '+${e.effectiveNetKcal.toStringAsFixed(0)}',
          onTap: open,
        ),
      ));
    }
    for (final e in widget.controller.alcoholEntries) {
      if (!isSameLocalDay(e.consumedAt, day)) continue;
      rows.add((
        at: e.consumedAt,
        row: DesignListRow(
          icon: AppIcons.alcohol,
          time: _time(e.consumedAt),
          title: e.beverageName,
          value: e.totalCalories.toStringAsFixed(0),
          onTap: open,
        ),
      ));
    }
    rows.sort((a, b) => a.at.compareTo(b.at));
    return [for (final r in rows) r.row];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final markers = buildHistoryDayMarkers(
          foodEntries: widget.controller.foodEntries,
          exerciseEntries: widget.controller.exerciseEntries,
          alcoholEntries: widget.controller.alcoholEntries,
        );
        final grid = buildMonthCalendarGrid(_focusedMonth);
        final today = localDayStart(DateTime.now());
        final rows = _dayRows();

        return DesignPage(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DesignTitleBlock(
                title: '履歴',
                subtitle: '記録した日をカレンダーで振り返れます。',
              ),
              // Figma: 月送り
              DesignCard(
                elevated: false,
                radius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '前の月',
                      onPressed: () => _shiftMonth(-1),
                      icon: const DesignIcon(
                        Symbols.chevron_left_rounded,
                        size: 20,
                        color: AppColors.iconMuted,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _monthLabel(_focusedMonth),
                        textAlign: TextAlign.center,
                        style: AppTypography.titleM,
                      ),
                    ),
                    IconButton(
                      tooltip: '次の月',
                      onPressed: () => _shiftMonth(1),
                      icon: const DesignIcon(
                        Symbols.chevron_right_rounded,
                        size: 20,
                        color: AppColors.iconMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DesignCard(
                elevated: false,
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
                child: Column(
                  children: [
                    const _WeekdayHeaderRow(),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 0,
                          ),
                      itemCount: grid.length,
                      itemBuilder: (context, index) {
                        final day = grid[index];
                        if (day == null) {
                          return const SizedBox.shrink();
                        }
                        final marker =
                            markers[localDayStart(day)] ??
                            const HistoryDayMarkerInfo();
                        return _CalendarDayCell(
                          day: day.day,
                          marker: marker,
                          isToday: isSameLocalDay(day, today),
                          isSelected: isSameLocalDay(day, _selectedDay),
                          onTap: () => _onDayTap(day),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    const _CalendarLegend(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DesignSectionHeader(
                icon: AppIcons.calendar,
                title: formatJapaneseDateWithWeekday(_selectedDay),
                actionLabel: 'この日を開く',
                onAction: () => _openDayHistory(_selectedDay),
              ),
              const SizedBox(height: 4),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'この日の記録はありません',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyS.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                )
              else
                ...rows,
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _WeekdayHeaderRow extends StatelessWidget {
  const _WeekdayHeaderRow();

  static const _labels = ['日', '月', '火', '水', '木', '金', '土'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final label in _labels)
          Expanded(
            child: Center(
              child: Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: label == '日'
                      ? AppColors.textDanger
                      : AppColors.textMuted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: const [
        _LegendItem(color: AppColors.primaryGreen, label: '食事'),
        _LegendItem(color: AppColors.accentOrange, label: '運動'),
        _LegendItem(color: AppColors.accentWine, label: 'アルコール'),
        _LegendItem(
          colors: [AppColors.primaryGreen, AppColors.accentOrange],
          label: '食事＋運動',
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({this.color, this.colors = const [], required this.label});

  final Color? color;
  final List<Color> colors;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (colors.length >= 2) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colors.first,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 2),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colors.last,
              shape: BoxShape.circle,
            ),
          ),
        ] else
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.marker,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final int day;
  final HistoryDayMarkerInfo marker;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.bgPrimary : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$day',
              style: AppTypography.labelM.copyWith(
                color: isSelected
                    ? AppColors.textOnPrimary
                    : isToday
                    ? AppColors.textBrand
                    : AppColors.textPrimary,
                fontWeight: isToday || isSelected
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 2),
          _MarkerDots(marker: marker),
        ],
      ),
    );
  }
}

class _MarkerDots extends StatelessWidget {
  const _MarkerDots({required this.marker});

  final HistoryDayMarkerInfo marker;

  @override
  Widget build(BuildContext context) {
    if (marker.isEmpty) {
      return const SizedBox(height: 8);
    }

    final dots = <Widget>[];
    if (marker.hasFood) {
      dots.add(const _Dot(color: AppColors.primaryGreen));
    }
    if (marker.hasExercise) {
      dots.add(const _Dot(color: AppColors.accentOrange));
    }
    if (marker.hasAlcohol) {
      dots.add(const _Dot(color: AppColors.accentWine));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < dots.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          dots[i],
        ],
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
