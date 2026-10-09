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
