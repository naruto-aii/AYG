import 'record_clock.dart';

/// ユーザーのローカル日付（カレンダー日）ユーティリティ。
bool isSameLocalDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime localDayStart(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

/// 記録の壁時計がそのカレンダー日か。
///
/// 旧行は UTC の暦を壁時計として読み、新行（マイクロ秒 1 の印）だけ
/// [DateTime.toLocal] してから日を取る。合計と履歴は同じ壁時計で集計する。
bool isLoggedOnLocalDay(DateTime loggedAt, DateTime referenceDate) {
  return isSameLocalDay(civilClock(loggedAt), civilClock(referenceDate));
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
