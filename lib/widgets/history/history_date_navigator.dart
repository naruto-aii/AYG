import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/history_grouping.dart';
import '../../utils/local_date.dart';

/// 履歴タブ向けの日付切替バー（前日・翌日・今日へ戻る）。
class HistoryDateNavigator extends StatelessWidget {
  const HistoryDateNavigator({
    super.key,
    required this.selectedDate,
    required this.onSelectedDateChanged,
    this.onOpenCalendar,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectedDateChanged;
  final VoidCallback? onOpenCalendar;

  DateTime get _day => localDayStart(selectedDate.toLocal());

  bool get _isToday => isSameLocalDay(_day, DateTime.now());

  void _shiftDay(int delta) {
    onSelectedDateChanged(_day.add(Duration(days: delta)));
  }

  void _goToToday() {
    onSelectedDateChanged(localDayStart(DateTime.now()));
  }

  String get _label => dateLabelFor(_day, referenceDate: DateTime.now());

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '前日',
            onPressed: () => _shiftDay(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: InkWell(
              onTap: onOpenCalendar,
              borderRadius: BorderRadius.circular(AppSpacing.xs),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Column(
                  children: [
                    Text(
                      _label,
                      textAlign: TextAlign.center,
                      style: labelStyle,
                    ),
                    if (onOpenCalendar != null)
                      Text(
                        'カレンダーを開く',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: '翌日',
            onPressed: () => _shiftDay(1),
            icon: const Icon(Icons.chevron_right),
          ),
          if (!_isToday)
            TextButton(onPressed: _goToToday, child: const Text('今日へ')),
        ],
      ),
    );
  }
}
