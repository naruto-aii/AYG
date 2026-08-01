import '../models/alcohol_entry.dart';
import '../models/exercise_entry.dart';
import '../models/food_entry.dart';
import 'local_date.dart';

/// 履歴カレンダー上の日付マーカー（食事・運動・アルコール）。
class HistoryDayMarkerInfo {
  const HistoryDayMarkerInfo({
    this.hasFood = false,
    this.hasExercise = false,
    this.hasAlcohol = false,
  });

  final bool hasFood;
  final bool hasExercise;
  final bool hasAlcohol;

  bool get isEmpty => !hasFood && !hasExercise && !hasAlcohol;
}

DateTime historyLocalDateKey(DateTime loggedAt) {
  return localDayStart(loggedAt.toLocal());
}

/// 食事・運動・アルコール記録日ごとのマーカーを構築する。
Map<DateTime, HistoryDayMarkerInfo> buildHistoryDayMarkers({
  required List<FoodEntry> foodEntries,
  required List<ExerciseEntry> exerciseEntries,
  List<AlcoholEntry> alcoholEntries = const [],
}) {
  final foodDays = <DateTime>{};
  final exerciseDays = <DateTime>{};
  final alcoholDays = <DateTime>{};

  for (final entry in foodEntries) {
    foodDays.add(historyLocalDateKey(entry.loggedAt));
  }
  for (final entry in exerciseEntries) {
    exerciseDays.add(historyLocalDateKey(entry.loggedAt));
  }
  for (final entry in alcoholEntries) {
    alcoholDays.add(historyLocalDateKey(entry.consumedAt));
  }

  final markers = <DateTime, HistoryDayMarkerInfo>{};
  for (final day in {...foodDays, ...exerciseDays, ...alcoholDays}) {
    markers[day] = HistoryDayMarkerInfo(
      hasFood: foodDays.contains(day),
      hasExercise: exerciseDays.contains(day),
      hasAlcohol: alcoholDays.contains(day),
    );
  }
  return markers;
}

/// 指定月のカレンダーグリッド（日曜始まり）。月外は null。
List<DateTime?> buildMonthCalendarGrid(DateTime month) {
  final firstOfMonth = DateTime(month.year, month.month, 1);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final leadingEmpty = firstOfMonth.weekday % 7;

  final cells = <DateTime?>[
    for (var i = 0; i < leadingEmpty; i++) null,
    for (var day = 1; day <= daysInMonth; day++)
      DateTime(month.year, month.month, day),
  ];

  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return cells;
}
