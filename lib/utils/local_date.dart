/// ユーザーのローカル日付（カレンダー日）ユーティリティ。
bool isSameLocalDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime localDayStart(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

/// 記録の時計がそのカレンダー日か。
///
/// 食事の `logged_at` はローカルの壁時計を、オフセット無しの
/// [DateTime.toIso8601String] で保存している。Supabase の `timestamptz` は
/// その時計を UTC として返し、[DateTime.parse] は同じ年月日時刻の UTC 値を
/// 作る。ここで [DateTime.toLocal] すると端末オフセットがもう一度足され、
/// 夕方以降の記録が翌日へずれてホームの合計だけ 0 に戻る。履歴の行は
/// 時計の日付のまま残る。合計はその履歴と同じ日付で集計する。
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

/// 日本語の曜日（日〜土）。
const List<String> japaneseWeekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

/// 「2025年4月12日（土）」の形にする。
String formatJapaneseDateWithWeekday(DateTime date) {
  final weekday = japaneseWeekdayLabels[date.weekday - 1];
  return '${date.year}年${date.month}月${date.day}日（$weekday）';
}
