import 'package:flutter/material.dart';

import '../../utils/local_date.dart';
import 'history_date_navigator.dart';

/// 食事・運動タブ共通の日付ナビ + リスト本体。
class HistoryTabBody extends StatelessWidget {
  const HistoryTabBody({
    super.key,
    required this.selectedDate,
    required this.onSelectedDateChanged,
    required this.listChild,
    this.onOpenCalendar,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectedDateChanged;
  final Widget listChild;
  final VoidCallback? onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HistoryDateNavigator(
          selectedDate: selectedDate,
          onSelectedDateChanged: (date) {
            onSelectedDateChanged(localDayStart(date));
          },
          onOpenCalendar: onOpenCalendar,
        ),
        Expanded(child: listChild),
      ],
    );
  }
}

/// 選択日の新規記録用初期日時（現在時刻の時分を選択日に載せる）。
DateTime initialLoggedAtForSelectedDay(DateTime selectedDay) {
  final now = DateTime.now();
  final day = selectedDay.toLocal();
  return DateTime(day.year, day.month, day.day, now.hour, now.minute);
}
