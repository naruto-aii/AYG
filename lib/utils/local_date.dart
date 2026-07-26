/// ユーザーのローカル日付（カレンダー日）ユーティリティ。
bool isSameLocalDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime localDayStart(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

bool isLoggedOnLocalDay(DateTime loggedAt, DateTime referenceDate) {
  return isSameLocalDay(loggedAt, referenceDate);
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
