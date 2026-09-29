import '../models/exercise_entry.dart';
import '../models/food_entry.dart';
import 'local_date.dart';

/// 履歴画面向けの日付グループ。
class HistoryDateGroup<T> {
  const HistoryDateGroup({
    required this.date,
    required this.label,
    required this.items,
  });

  final DateTime date;
  final String label;
  final List<T> items;
}

bool _isSameDay(DateTime a, DateTime b) {
  return isSameLocalDay(a.toLocal(), b.toLocal());
}

DateTime _dateOnly(DateTime value) {
  return localDayStart(value.toLocal());
}

String dateLabelFor(DateTime date, {required DateTime referenceDate}) {
  final today = _dateOnly(referenceDate);
  final target = _dateOnly(date);
  final difference = today.difference(target).inDays;

  return switch (difference) {
    0 => '今日',
    1 => '昨日',
    _ => '${date.year}/${date.month}/${date.day}',
  };
}

/// 記録時刻の昇順で並べ替え。
List<FoodEntry> sortFoodEntriesByLoggedAt(List<FoodEntry> entries) {
  final sorted = List<FoodEntry>.from(entries)
    ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
  return sorted;
}

/// 日付単位でグルーピング。将来の日付切替に備え、todayOnly=false で全期間に拡張可能。
List<HistoryDateGroup<FoodEntry>> groupFoodEntriesByDate(
  List<FoodEntry> entries, {
  required DateTime referenceDate,
  bool todayOnly = true,
}) {
  final filtered = todayOnly
      ? entries
            .where((entry) => _isSameDay(entry.loggedAt, referenceDate))
            .toList()
      : List<FoodEntry>.from(entries);

  final grouped = <DateTime, List<FoodEntry>>{};
  for (final entry in filtered) {
    final key = _dateOnly(entry.loggedAt);
    grouped.putIfAbsent(key, () => []).add(entry);
  }

  final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

  return dates
      .map(
        (date) => HistoryDateGroup<FoodEntry>(
          date: date,
          label: dateLabelFor(date, referenceDate: referenceDate),
          items: sortFoodEntriesByLoggedAt(grouped[date]!),
        ),
      )
      .toList();
}

List<HistoryDateGroup<ExerciseEntry>> groupExerciseEntriesByDate(
  List<ExerciseEntry> entries, {
  required DateTime referenceDate,
  bool todayOnly = true,
}) {
  final filtered = todayOnly
      ? entries
            .where((entry) => _isSameDay(entry.loggedAt, referenceDate))
            .toList()
      : List<ExerciseEntry>.from(entries);

  final grouped = <DateTime, List<ExerciseEntry>>{};
  for (final entry in filtered) {
    final key = _dateOnly(entry.loggedAt);
    grouped.putIfAbsent(key, () => []).add(entry);
  }

  final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

  return dates
      .map(
        (date) => HistoryDateGroup<ExerciseEntry>(
          date: date,
          label: dateLabelFor(date, referenceDate: referenceDate),
          items: List<ExerciseEntry>.from(grouped[date]!)
            ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt)),
        ),
      )
      .toList();
}

int daysUntilGoalDate(DateTime targetDate, {DateTime? referenceDate}) {
  final now = _dateOnly(referenceDate ?? DateTime.now());
  final target = _dateOnly(targetDate);
  return target.difference(now).inDays;
}
