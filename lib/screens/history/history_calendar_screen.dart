import 'package:flutter/material.dart';

import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/history_calendar_markers.dart';
import '../../utils/local_date.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/layout/app_content_constraint.dart';
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
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

  String _monthLabel(DateTime month) => '${month.year}年${month.month}月';

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

        return Scaffold(
          appBar: AppBar(title: const Text('履歴')),
          body: SafeArea(
            child: AppContentConstraint(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _shiftMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          _monthLabel(_focusedMonth),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _shiftMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _CalendarLegend(),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      children: [
                        const _WeekdayHeaderRow(),
                        const SizedBox(height: AppSpacing.xs),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                mainAxisSpacing: AppSpacing.xs,
                                crossAxisSpacing: AppSpacing.xs,
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
                            final isToday = isSameLocalDay(day, today);
                            return _CalendarDayCell(
                              day: day.day,
                              marker: marker,
                              isToday: isToday,
                              onTap: () => _openDayHistory(day),
                            );
                          },
                        ),
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
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarLegend extends StatelessWidget {
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
  const _LegendItem({
    this.color,
    this.colors = const [],
    required this.label,
  });

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
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.secondaryText,
          ),
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
    required this.onTap,
  });

  final int day;
  final HistoryDayMarkerInfo marker;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
      color: isToday ? AppColors.primaryGreen : AppColors.primaryText,
    );

    return Material(
      color: isToday ? AppColors.heroBackground : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.xs),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$day', style: textStyle),
            const SizedBox(height: 2),
            _MarkerDots(marker: marker),
          ],
        ),
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
