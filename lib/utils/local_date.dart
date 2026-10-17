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

/// DB の壁時計列（`logged_at` など）を端末の壁時計の [DateTime] に戻す。
///
/// 端末はオフセット無しで送り、`timestamptz` はその時計を UTC として返す。
/// UTC のまま端末 DB（Isar）に入れると、読み出し時に `toLocal()` され
/// 端末オフセット分（日本なら +9 時間）ずれる。次の同期でその値を送り返すと
/// サーバーの値も +9 時間ずれ、同期のたびに積み重なる。年月日時刻をそのまま
/// ローカル時刻として持てば、何度往復しても同じ壁時計になる。
DateTime wallClockFromDb(String raw) {
  final parsed = DateTime.parse(raw);
  return parsed.isUtc ? _asLocalWallClock(parsed) : parsed;
}

/// 端末の壁時計を、オフセット無しの文字列で DB に送る。
///
/// UTC の値は [wallClockFromDb] を通っていない古い経路の値で、年月日時刻が
/// そのまま壁時計を表す。どちらも同じ年月日時刻の文字列にする。
String wallClockToDb(DateTime value) {
  final wall = value.isUtc ? _asLocalWallClock(value) : value;
  return wall.toIso8601String();
}

DateTime _asLocalWallClock(DateTime value) {
  return DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
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
