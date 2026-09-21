/// ユーザーのローカル日付（カレンダー日）ユーティリティ。
bool isSameLocalDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime localDayStart(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

bool isLoggedOnLocalDay(DateTime loggedAt, DateTime referenceDate) {
  return isSameLocalDay(loggedAt.toLocal(), referenceDate.toLocal());
}

List<T> filterLoggedOnLocalDay<T>({
  required List<T> entries,
  required DateTime referenceDate,
  required DateTime Function(T entry) readLoggedAt,
}) {
  return entries
      .where((entry) => isLoggedOnLocalDay(readLoggedAt(entry), referenceDate))
      .toList();
}

/// 日本語の曜日（日〜土）。
const List<String> japaneseWeekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

/// 「2025年4月12日（土）」の形にする。
String formatJapaneseDateWithWeekday(DateTime date) {
  final weekday = japaneseWeekdayLabels[date.weekday - 1];
  return '${date.year}年${date.month}月${date.day}日（$weekday）';
}
